---
name: plan-review-cycle
description: Guides a structured plan→self-review→implement→self-review→fix cycle. Use when starting any non-trivial implementation task. Applies to all tech stacks (C#, .NET, Unity, Terraform, AWS, GCP). Always self-review plans before presenting, always review implementations for performance and security, and always ask before committing or pushing.
---

# Plan → Review → Implement → Review → Fix

## Phase 1: Research

Before drafting any plan:
- Read relevant source files; never assume file contents.
- Identify affected interfaces, tests, and dependencies.
- Check for existing patterns in the codebase to stay consistent.

## Phase 2: Plan

Draft a concise, actionable plan:
- List specific files and line ranges to change.
- Note any new dependencies or breaking changes.
- Keep the plan proportional to the task — no over-engineering.

## Phase 3: Self-review the plan

Before presenting to the user, challenge the plan:

- [ ] Is there a simpler approach?
- [ ] Does it introduce unnecessary dependencies?
- [ ] Are there performance implications (hot paths, allocations, N+1 queries)?
- [ ] Are there security risks (injection, privilege escalation, exposed secrets)?
- [ ] Does it break backward compatibility unintentionally?

Revise the plan if any issue is found, then present it to the user.

## Phase 4: Wait for approval

Present the plan and **wait for explicit user confirmation** before implementing.
If the user approves, proceed to Phase 5. If they request changes, revise and repeat Phase 3.

## Phase 5: Implement

Execute the approved plan. Make the smallest diff that satisfies the requirements.
If unexpected complexity arises, stop and report back rather than silently expanding scope.

## Phase 6: Self-review the implementation

After implementation, review the changes:

**Performance**
- [ ] No unnecessary allocations in hot paths
- [ ] No unbounded loops or O(n²) operations on large data sets
- [ ] Async operations use cancellation tokens where applicable

**Security**
- [ ] No hardcoded secrets or credentials
- [ ] No untrusted input used in SQL, shell commands, or file paths without validation
- [ ] Least-privilege principle applied (IAM roles, service accounts, permissions)

**Correctness**
- [ ] Edge cases handled (null, empty, concurrent access)
- [ ] Error paths return meaningful errors, not silent failures

Fix any issues found before proceeding.

## Phase 7: Commit / push

**Always ask the user before committing or pushing.**
Suggest a commit message but do not run `git commit` or `git push` without explicit approval.
