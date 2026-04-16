---
name: unity-dev
description: Unity development patterns covering MonoBehaviour lifecycle, GC avoidance, UniTask async, object pooling, and UniCli Editor automation. Use when working on Unity projects, editing Assets/ or Packages/, writing MonoBehaviour/ScriptableObject code, or automating the Unity Editor.
---

# Unity Development

## MonoBehaviour lifecycle order

`Awake` → `OnEnable` → `Start` → `Update` / `FixedUpdate` / `LateUpdate` → `OnDisable` → `OnDestroy`

- Use `Awake` for self-initialization (references, field setup).
- Use `Start` for cross-object initialization (accessing other components that need `Awake` first).
- Never call `GetComponent` in `Update`; cache it in `Awake`.

## GC avoidance (hot paths)

- **No allocations in `Update`**: avoid `new`, LINQ, string concatenation, boxing, closures.
- Use `ObjectPool<T>` (`UnityEngine.Pool`) instead of `Instantiate`/`Destroy` for frequently spawned objects.
- Cache `WaitForSeconds` instances; never create them inside coroutines.
- Use `StringBuilder` for dynamic UI strings updated per frame.

```csharp
private readonly WaitForSeconds _wait = new WaitForSeconds(1f);

private IEnumerator TickCoroutine()
{
    while (true)
    {
        yield return _wait;
        Tick();
    }
}
```

## Async (UniTask)

Prefer `UniTask` over `System.Threading.Tasks.Task` in Unity projects:
- `UniTask.Delay` instead of coroutines for time-based waits.
- `UniTask.WaitUntil` for condition polling.
- Always pass `CancellationToken` (use `this.GetCancellationTokenOnDestroy()` on MonoBehaviour).

```csharp
private async UniTaskVoid LoadAsync(CancellationToken ct)
{
    await UniTask.Delay(TimeSpan.FromSeconds(1f), cancellationToken: ct);
    var handle = Addressables.LoadAssetAsync<Sprite>("icon");
    await handle.ToUniTask(cancellationToken: ct);
    _image.sprite = handle.Result;
}
```

## UniCli Editor automation

When `unicli` CLI is available (Unity Editor must be open with `com.yucchiy.unicli-server`):

```bash
# Import asset after creating/modifying a file under Assets/
unicli exec AssetDatabase.Import --path "Assets/MyScript.cs" --json

# Verify compilation after C# changes
unicli exec Compile --json

# Run EditMode tests
unicli exec RunTests --mode EditMode --resultFilter failures --json

# Run PlayMode tests
unicli exec RunTests --mode PlayMode --resultFilter failures --json
```

Rules when using UniCli:
1. Always run `AssetDatabase.Import` after creating or modifying any file under `Assets/` or `Packages/`.
2. Always run `Compile` after C# changes and verify it reports no errors before proceeding.
3. Never create `.meta` files manually — let Unity generate them via `AssetDatabase.Import`.
4. If the Editor connection fails, retry 2–3 times, then ask the user to confirm the Editor is running.

## ScriptableObject patterns

- Use `ScriptableObject` for shared configuration and data that doesn't change at runtime.
- Create via `[CreateAssetMenu]`; never instantiate directly with `new`.
- Avoid storing runtime state in ScriptableObjects (they persist between Play sessions in the Editor).

## Assembly definitions

- Split code into assemblies with `.asmdef` files to reduce compilation scope.
- Separate Editor-only code into assemblies with `"includePlatforms": ["Editor"]`.
- Reference only what each assembly needs; avoid circular references.
