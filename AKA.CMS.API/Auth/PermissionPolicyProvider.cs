using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;

namespace AKA.CMS.API.Auth;

public sealed class PermissionCatalog
{
    private readonly HashSet<string> _policyNames = new(StringComparer.OrdinalIgnoreCase);

    public void Load(IEnumerable<string> policyNames)
    {
        _policyNames.Clear();
        foreach (var name in policyNames)
            _policyNames.Add(name);
    }

    public bool Contains(string policyName) => _policyNames.Contains(policyName);
}

public sealed class PermissionPolicyProvider(
    IOptions<AuthorizationOptions> options,
    PermissionCatalog catalog) : IAuthorizationPolicyProvider
{
    private readonly DefaultAuthorizationPolicyProvider _fallback = new(options);

    public Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        if (!policyName.StartsWith("Permissions:", StringComparison.OrdinalIgnoreCase))
            return _fallback.GetPolicyAsync(policyName);

        if (!catalog.Contains(policyName))
            return Task.FromResult<AuthorizationPolicy?>(null);

        var claimValue = policyName["Permissions:".Length..];
        var policy = new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .AddRequirements(new PermissionAuthorizationRequirement(claimValue))
            .Build();
        return Task.FromResult<AuthorizationPolicy?>(policy);
    }

    public Task<AuthorizationPolicy> GetDefaultPolicyAsync() => _fallback.GetDefaultPolicyAsync();
    public Task<AuthorizationPolicy?> GetFallbackPolicyAsync() => _fallback.GetFallbackPolicyAsync();
}
