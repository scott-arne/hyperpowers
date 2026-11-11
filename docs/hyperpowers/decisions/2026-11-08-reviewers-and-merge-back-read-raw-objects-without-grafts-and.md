# Reviewers and merge-back read raw objects without grafts, and symbolic integration and plan refs are refused

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 9)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**Reviewers and merge-back read raw objects without grafts, and symbolic
integration and plan refs are refused.** The careless-model framing of
2026-10-14 still holds; these checks are cheap and close paths the
reviewers found.

## What implementation changed

The decision shipped with two refinements. `review-package` and `cmd_merge_back` both set `GIT_NO_REPLACE_OBJECTS=1` and `GIT_GRAFT_FILE`, but to `/dev/null/no-grafts` rather than the spec's `/dev/null`, because `/dev/null` makes git print its graft-deprecation advice on every call. The symbolic-ref refusal is built on a new `direct_ref_commit` helper, which reads the ref's symbolic status and value in one `for-each-ref` call, and amend also checks before its first write, not only in the attempt loop. Both swaps use `update-ref --no-deref`, and `hp_plan_overlaps` now takes the commit the caller read instead of a ref name, so a ref made symbolic and restored during the scan cannot change which amendment records count.
