# GitHub Copilot instructions

<!-- Copy this file to .github/copilot-instructions.md in each project. -->

## Workflow

For non-trivial tasks, always follow this cycle:

1. Read relevant source files before proposing changes.
2. Propose a plan and self-review it for simpler alternatives, performance, and security.
3. Implement after approval.
4. Self-review the implementation (performance, security, correctness).
5. Ask before committing or pushing.

## C# / .NET

- Explicit `private` on every non-public member.
- XML documentation on all public types and members.
- Propagate `CancellationToken` through async call chains.
- `ConfigureAwait(false)` in library code.
- No `.Result` or `.Wait()` — use `await`.

## Unity

- No allocations in `Update`; cache component references in `Awake`.
- Use `UniTask` for async operations; pass `CancellationToken` from `this.GetCancellationTokenOnDestroy()`.
- After modifying files under `Assets/`, import via `AssetDatabase.Refresh()` or UniCli.
- Verify compilation after C# changes.

## Terraform

- `terraform plan -out=tfplan` before every apply.
- Pin providers to `~> MAJOR.MINOR`.
- Remote backend with encryption and state locking.
- No hardcoded credentials; use IAM roles / Workload Identity.

## AWS / GCP

- IAM least privilege: no wildcard actions without explicit justification.
- Secrets in AWS Secrets Manager or GCP Secret Manager.
- Encryption at rest on all storage resources.
- Audit logging enabled.

## General

- No comments that merely restate what the code does.
- No emojis unless explicitly requested.
- Make the smallest diff that satisfies the requirement.
