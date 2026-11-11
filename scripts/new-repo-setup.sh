#!/usr/bin/env bash
# Set up a new repo like the others: reviewbot + bot GitHub App.
#
# Usage:   new-repo-setup owner/repo [owner/repo ...]
#          (symlinked once: ln -s "$PWD/scripts/new-repo-setup.sh" ~/.local/bin/new-repo-setup)
# Needs:   gh signed in as anentropic; macOS keychain entries (see "One-time setup").
#
# What it does per repo:
#   - sets BOT_APP_ID and BOT_APP_PRIVATE_KEY as Actions AND Dependabot secrets
#   - creates the `claude-review` label
#   - on anentropic/* repos only: invites anentropic-reviewbot (write) and sets
#     CLAUDE_CODE_OAUTH_TOKEN (s-layer has the bot as a member and the token as an org secret)
#
# Not done here: adding the repo to the Claude GitHub App and the bot app (ID 5321164)
# installations. GitHub only allows that API with a GitHub App user token, which gh
# doesn't have, so the script prints the settings link at the end instead.
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

echo
echo "Check both apps (Claude and the bot app) have access to: $*"
echo "  https://github.com/settings/installations  (s-layer: https://github.com/organizations/s-layer/settings/installations)"
