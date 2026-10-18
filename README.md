# github-reviewbot

Review bot for my GitHub PRs.

Request a review from `anentropic-reviewbot` on a PR (or add the
`claude-review` label) and Claude reviews it, posting a single review: a
short summary plus inline comments on the problems it finds. As one review it
sends one notification, not one per comment. When it's done the request or
label is cleared, so you can ask again.

Asking again after new commits runs a re-review: Claude reviews only what
changed in the PR's files since its last review, and says which of the
earlier findings are fixed. Asking again on a commit it already reviewed
runs a full review.

Only one review runs per PR at a time: asking again while one is running (or
requesting a review and adding the label together) cancels the older run.

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
      statuses: write
    uses: anentropic/github-reviewbot/.github/workflows/review.yml@main
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Draft PRs are skipped, so mark the PR ready before requesting a review.

Each run sets a one-line "Claude review" status in the PR's checks list:
reviewing, reviewed, failed (including a run that ended without posting its
summary), or skipped with the reason (a draft PR, or a PR that changes the
review workflow, which the Claude app only runs once it matches the default
branch).

### Options

The shared workflow has three settings. They go in the caller workflow
file above, not in a PR comment, and apply to every review on that repo.
Add a `with:` block under `uses:` to change them:

```yaml
    uses: anentropic/github-reviewbot/.github/workflows/review.yml@main
    with:
      model: sonnet
```

- `model`: the Claude model to review with (default `opus`)
- `reviewer`: the account whose review request is cleared after a review
  (default `anentropic-reviewbot`)
- `label`: the label removed after a review (default `claude-review`)

If you change `reviewer` or `label`, change the matching name in the
`if:` line too, since that line decides which requests start a review.
