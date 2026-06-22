---
name: create-pr-from-ticket
description: >-
  Create a GitHub pull request from a GitHub issue/ticket URL and link the
  ticket inside the PR. Use this when the user asks to open or create a PR from
  a ticket, issue, or task URL. Derives the PR title from the ticket title,
  summarizes changes as a bulleted list, adds sensible tests, targets the main
  branch by default, and never merges the PR automatically.
---

# Create a PR from a GitHub Ticket

Open a pull request that implements a GitHub ticket and links back to it.

## Inputs

- **Ticket URL** (required): a GitHub issue URL, e.g.
  `https://github.com/<owner>/<repo>/issues/<number>`.
- **Base branch** (optional): the branch the PR targets. Defaults to `main`.

If the ticket URL is missing, ask the user for it before proceeding.

## Rules

1. **PR title from the ticket title.** Fetch the ticket and base the PR title on
   its title. Do not invent an unrelated title.
2. **Bulleted change summary.** The PR body must contain a short, bulleted list
   of the changes made — concise, one bullet per meaningful change.
3. **Meet the acceptance criteria.** If the ticket lists acceptance criteria (or
   a definition of done, checklist, or required behaviors), the implementation
   must satisfy every item. If any criterion is ambiguous or cannot be met, stop
   and ask the user rather than opening a partial PR.
4. **Add sensible tests.** Create or update tests that make sense for the change
   given the language, framework, and existing testing conventions in the repo.
   Match the project's current standards and practices. Do not add tests that do
   not apply to the change. When the ticket defines acceptance criteria, the
   tests must explicitly verify each criterion.
5. **Never auto-merge.** Do NOT merge the PR. Merging is reserved for the human
   author/reviewer. Do not enable auto-merge, squash, or rebase-merge.
6. **Target `main` by default.** Point the PR at the `main` branch unless the
   user explicitly specifies a different base branch.
7. **Link the ticket in the PR.** Reference the ticket in the PR body using a
   linking keyword (e.g. `Closes #<number>`) plus the full ticket URL so the
   ticket and PR are connected.

## Procedure

### 1. Read the ticket

Extract `<owner>`, `<repo>`, and `<number>` from the URL and fetch the title and
body:

```sh
gh issue view <number> --repo <owner>/<repo> --json number,title,body,url
```

Use the title for the PR title and the body to understand the required work.
Identify any acceptance criteria in the ticket (commonly a "Acceptance
Criteria", "Definition of Done", or checklist section). Capture each criterion
so it can drive both the implementation and the tests; if none are stated,
infer the expected behavior from the ticket description.

### 2. Use the current branch

> **Note:** Create and check out your own working branch *before* running this
> skill. This skill does not create or switch branches — all changes are made in
> whatever local branch is checked out at the time it runs.

Confirm the checked-out branch is the one you intend to commit to (and is not
the base branch itself):

```sh
git branch --show-current
```

If you are still on the base branch, stop and ask the user to create/switch to a
working branch before continuing.

### 3. Implement the change

Make the code changes required to resolve the ticket, following the repository's
existing conventions and structure. Ensure the change satisfies every
acceptance criterion captured in step 1.

### 4. Add tests

Add or update tests appropriate to the change and the project's stack. Cover
each acceptance criterion from step 1 with a test that verifies it, so a passing
suite demonstrates the criteria are met. Discover how tests are run and confirm
they pass before opening the PR. Examples:

- Elixir / Phoenix: `mix test`
- JavaScript / TypeScript: `npm test` (or the project's configured runner)
- Python: `pytest`

Use whatever the repository already uses; do not introduce a new test framework.

### 5. Commit and push

Commit and push the current branch (the one confirmed in step 2).

Be thoughtful about commit organization: group changes into logical commits by
feature step (or whatever grouping is most coherent) so the history is easy to
review, rather than dumping everything into one opaque commit. Use clear,
descriptive messages for each commit.

Commit titles must be capitalized like a title and always start with a verb —
e.g. `Add Tests for Tracking Webhook Controller`.

```sh
# Stage and commit related changes together, one logical step at a time:
git add <paths-for-this-step>
git commit -m "<Title-Case verb-first message, referencing the ticket>"
# ...repeat for each logical group, then push the branch:
git push -u origin "$(git branch --show-current)"
```

### 6. Open the PR (targeting `main` by default)

Build the PR body with a bulleted change list and a link to the ticket, then
create the PR. Do not merge it.

```sh
gh pr create \
  --base main \
  --title "<title from ticket>" \
  --body "$(cat <<'EOF'
## Summary

- <change 1>
- <change 2>
- <change 3>

## Acceptance criteria

- [x] <criterion 1 — how it is met / which test verifies it>
- [x] <criterion 2 — how it is met / which test verifies it>

## Tests

- <test added/updated, which criteria it verifies, and how it was verified>

Closes #<number>
Ticket: <full ticket URL>
EOF
)"
```

Replace `--base main` only if the user specified a different base branch.
Include the **Acceptance criteria** section only when the ticket actually
defines criteria; omit it otherwise.

### 7. Report back

Share the created PR URL with the user. Explicitly note that the PR has NOT been
merged and that merging is up to the human author/reviewer.

## Guardrails

- Never run `gh pr merge`, never enable auto-merge, and never push directly to
  `main`.
- If tests fail, fix them before opening the PR rather than opening a broken PR.
- Do not open the PR if any stated acceptance criterion is unmet or unverified
  by tests; resolve it or ask the user first.
- If the ticket URL is not a valid GitHub issue URL, stop and ask the user.
