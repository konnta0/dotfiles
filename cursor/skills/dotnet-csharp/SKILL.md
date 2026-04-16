---
name: dotnet-csharp
description: .NET and C# development patterns covering async/await, dependency injection, testing, NuGet, and project structure. Use when working on .NET projects, C# code, ASP.NET Core, or class libraries.
---

# .NET / C# Development

## async / await

- Always propagate `CancellationToken` through async call chains; accept it as the last parameter.
- Use `ConfigureAwait(false)` in library code (not UI / Unity main-thread code).
- Prefer `ValueTask` for hot paths that often complete synchronously; use `Task` for all other async methods.
- Never use `async void` except for event handlers; return `Task` instead.
- Avoid `.Result` and `.Wait()` — they deadlock in synchronization-context environments.

```csharp
public async Task<Result> ProcessAsync(Input input, CancellationToken ct = default)
{
    var data = await _repo.GetAsync(input.Id, ct).ConfigureAwait(false);
    return await _service.TransformAsync(data, ct).ConfigureAwait(false);
}
```

## Dependency Injection

- Register services in `IServiceCollection` extensions, not in `Program.cs` directly.
- Prefer constructor injection; avoid service locator (`IServiceProvider` as a dependency).
- Lifetime rules: Singleton > Scoped > Transient — never inject a shorter-lived service into a longer-lived one.
- Use `IOptions<T>` / `IOptionsSnapshot<T>` for configuration binding.

```csharp
public static IServiceCollection AddMyFeature(this IServiceCollection services, IConfiguration config)
{
    services.Configure<MyOptions>(config.GetSection("MyFeature"));
    services.AddScoped<IMyService, MyService>();
    return services;
}
```

## Testing (xUnit)

- Arrange / Act / Assert with a blank line between each section.
- Use `FluentAssertions` for readable assertions.
- Stub external dependencies with `NSubstitute` or `Moq`; avoid testing implementation details.
- Name tests: `MethodName_Condition_ExpectedBehavior`.

```csharp
[Fact]
public async Task ProcessAsync_WhenInputIsValid_ReturnsSuccess()
{
    var repo = Substitute.For<IRepository>();
    repo.GetAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>()).Returns(new Data());
    var sut = new MyService(repo);

    var result = await sut.ProcessAsync(new Input(Guid.NewGuid()));

    result.IsSuccess.Should().BeTrue();
}
```

## NuGet / Project structure

- Use Central Package Management (`Directory.Packages.props`) in multi-project solutions.
- Pin transitive packages explicitly when a CVE or breaking change affects them.
- One `<Project>` type per `.csproj`; avoid mixing library and executable targets.
- Prefer `<Nullable>enable</Nullable>` and `<ImplicitUsings>enable</ImplicitUsings>` globally via `Directory.Build.props`.

## Performance checklist

- [ ] Hot-path allocations minimized (use `Span<T>`, `ArrayPool<T>`, `stackalloc` where appropriate)
- [ ] `StringBuilder` used for repeated string concatenation
- [ ] `IEnumerable<T>` not enumerated multiple times (materialize with `.ToList()` / `.ToArray()` when needed)
- [ ] Large struct copies avoided — pass `in` or use reference types
