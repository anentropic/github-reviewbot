#!/usr/bin/env bash
# Set up a new repo like the others: reviewbot + bot GitHub App.
#
# Usage:   scripts/new-repo-setup.sh owner/repo [owner/repo ...]
# Needs:   gh signed in as anentropic; macOS keychain entries (see "One-time setup").
#
# What it does per repo:
#   - adds the repo to the Claude GitHub App and the bot app (ID 5321164) installations
#   - sets BOT_APP_ID and BOT_APP_PRIVATE_KEY as Actions AND Dependabot secrets
#   - creates the `claude-review` label
#   - on anentropic/* repos only: invites anentropic-reviewbot (write) and sets
#     CLAUDE_CODE_OAUTH_TOKEN (s-layer has the bot as a member and the token as an org secret)
#
# In-repo files (claude-review.yml, dependabot-automerge.yml, weekly.yml, the AGENTS.md
# "Opening pull requests" section) come from cookiecutter-python-uv-library or a PR.
#
# One-time setup (keychain, login keychain):
#   The PEM is stored base64-encoded, because `security -w` prints multi-line values as hex.
#     security add-generic-password -U -a "$USER" -s bot-app-private-key -w "$(base64 -i path/to/key.pem)"
#     security add-generic-password -U -a "$USER" -s claude-code-oauth-token -w
#   (the second one prompts for the value: paste the token from `claude setup-token`)
#   Then delete the downloaded .pem.
#
# After running on an anentropic/* repo, accept the invite as anentropic-reviewbot:
#   https://github.com/notifications  (or: gh api user/repository_invitations)
set -euo pipefail

APP_ID=5321164
BOT=anentropic-reviewbot

[ $# -ge 1 ] || { echo "usage: $0 owner/repo [owner/repo ...]" >&2; exit 1; }

kc() { security find-generic-password -s "$1" -w; }
PEM=$(kc bot-app-private-key | base64 -d)
TOKEN=""

for r in "$@"; do
  echo "== $r"
  owner=${r%%/*}

  repo_id=$(gh api "repos/$r" --jq .id)
  for sel in '.app_slug == "claude"' ".app_id == $APP_ID"; do
    read -r inst_id selection < <(gh api user/installations --paginate \
      --jq ".installations[] | select($sel and .account.login == \"$owner\")
            | \"\\(.id) \\(.repository_selection)\"") || true
    if [ -z "${inst_id:-}" ]; then
      echo "  app ($sel) not installed on $owner; install it first"
    elif [ "$selection" = all ]; then
      echo "  app ($sel) already covers all $owner repos"
    elif gh api -X PUT "user/installations/$inst_id/repositories/$repo_id" --silent; then
      echo "  app ($sel) installed"
    else
      echo "  could not add app ($sel) via API; add it at https://github.com/settings/installations"
    fi
  done

  for store in actions dependabot; do
    gh secret set BOT_APP_ID --app "$store" --repo "$r" --body "$APP_ID"
    printf '%s\n' "$PEM" | gh secret set BOT_APP_PRIVATE_KEY --app "$store" --repo "$r"
  done
  echo "  bot app secrets set (actions + dependabot)"

  gh label create claude-review --repo "$r" --color 7057ff \
    --description "Request a Claude review" --force >/dev/null
  echo "  claude-review label ok"

  if [ "$owner" = anentropic ]; then
    [ -n "$TOKEN" ] || TOKEN=$(kc claude-code-oauth-token)
    gh api -X PUT "repos/$r/collaborators/$BOT" -f permission=push --silent
    printf '%s' "$TOKEN" | gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo "$r"
    echo "  $BOT invited, CLAUDE_CODE_OAUTH_TOKEN set (accept the invite as $BOT)"
  fi
done
