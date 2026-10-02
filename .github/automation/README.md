# Release preparation

Run **Prepare release** on `master` after the intended changes have been merged.
The default `minor` + `alpha` selection advances the pre-1.0 series without
declaring a stable v1.0 release. Use `prerelease` to advance an existing
`-alpha.N` version, or `promote` with the stable channel when that exact alpha
version is ready to become stable. A large change set alone does not require
the `major` option.

The preparation run compares the previous published release with the frozen
`master` commit. It retains commit and PR text as context, analyzes net-changed
files in subsystem batches, and creates a ledger of candidate changes. Each
comparison must support a candidate or have a recorded reason for being
ignored. The final pass accounts for every candidate before rendering one
changelog entry. The same entry becomes the GitHub release body; evidence IDs
stay in the review artifact, not the public notes.

Review the generated release PR and its `release-review` artifact before
merging. In particular, inspect `review.md` for omitted candidates and
uncertainties, and `inventory.json` for excluded paths. The PR changes only
`CHANGELOG.md` and `.github/release-state.json`. If `master` advances, close
the stale release PR and prepare a new one.

If preparation fails, use the optional **failed preparation run ID** to reuse
completed batches from an artifact with the same analysis format. To test one
batch or the final note generation without preparing another PR, run **Probe
release notes** on `develop` with that preparation run ID and a batch number or
`final`. GitHub shows a new manual workflow only after its workflow file exists
on the default branch.
