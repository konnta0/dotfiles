# Global Claude Code instructions

## Workflow

For any non-trivial task, follow the plan-review-cycle:

1. **Research first**: Read relevant files before proposing anything. Never assume file contents.
2. **Draft a plan**: List specific files, functions, and changes. Keep it proportional to the task.
3. **Self-review the plan**: Check for simpler alternatives, performance issues, and security risks before presenting it.
4. **Wait for approval**: Present the plan and wait for explicit confirmation before implementing.
5. **Implement**: Make the smallest diff that satisfies the requirements.
6. **Self-review the implementation**: Check for performance regressions and security issues.
7. **Ask before committing or pushing**: Always confirm with the user before running `git commit` or `git push`.

## Self-review criteria

**Performance**
- No unnecessary allocations in hot paths
- Async operations use cancellation tokens

**Security**
- No hardcoded secrets or credentials
- No untrusted input in SQL / shell commands / file paths without validation
- Least-privilege principle applied

## Tech stack conventions

**C# / .NET**
- Explicit `private` on every non-public member
- XML docs on all public API surface
- `ConfigureAwait(false)` in library code; propagate `CancellationToken`

**Unity**
- No allocations in `Update`; cache `GetComponent` results in `Awake`
- Run `unicli exec Compile --json` after C# changes if `unicli` is available
- Run `unicli exec AssetDatabase.Import` after any file changes under `Assets/`

**Terraform**
- Always `terraform plan -out=tfplan` before apply
- Pin providers to `~> MAJOR.MINOR`; never use floating versions
- Remote backend with encryption and state locking

**AWS / GCP**
- IAM least privilege; no wildcard actions without justification
- Secrets in Secrets Manager or Secret Manager, never in code
- Encryption at rest on all storage resources

## Communication

- Output in the same language the user writes in (Japanese if asked in Japanese).
- Do not add comments that just narrate what the code does.
- Do not use emojis unless the user explicitly requests them.
