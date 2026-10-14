# github-reviewbot

Review bot for my GitHub PRs.

Request a review from `anentropic-reviewbot` on a PR (or add the
`claude-review` label) and Claude reviews it: inline comments on the
problems it finds, plus a short summary comment. When it's done the request
or label is cleared, so asking again runs a fresh review.

GitHub doesn't let a GitHub App be requested as a reviewer, so the request
goes to the `anentropic-reviewbot` account. The review itself is posted by
the Claude GitHub App.

The review runs `.claude/commands/review-pr.md` from the PR's repo when
there is one. Otherwise it uses the generic command embedded in
`.github/workflows/review.yml`, which reads AGENTS.md, CLAUDE.md and
REVIEW.md for the project's own rules.

## Adding it to a repo

1. Install the Claude GitHub App on the repo
   (https://github.com/apps/claude).
2. Add a `CLAUDE_CODE_OAUTH_TOKEN` repo secret, from `claude setup-token`.
3. Invite `anentropic-reviewbot` as a collaborator, then accept the invite
   while signed in as `anentropic-reviewbot`.
4. Add `.github/workflows/claude-review.yml`:

```yaml
name: Claude Review

on:
  pull_request:
    types: [review_requested, labeled]

jobs:
  review:
    if: >-
      (github.event.action == 'review_requested' && github.event.requested_reviewer.login == 'anentropic-reviewbot') ||
      (github.event.action == 'labeled' && github.event.label.name == 'claude-review')
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
    uses: anentropic/github-reviewbot/.github/workflows/review.yml@main
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Draft PRs are skipped, so mark the PR ready before requesting a review.

Inputs you can pass with `with:` are `model` (default `opus`), `reviewer`
(default `anentropic-reviewbot`) and `label` (default `claude-review`).
