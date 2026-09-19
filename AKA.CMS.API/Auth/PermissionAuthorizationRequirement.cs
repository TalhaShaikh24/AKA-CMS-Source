using Microsoft.AspNetCore.Authorization;

namespace AKA.CMS.API.Auth;

public sealed class PermissionAuthorizationRequirement(string claimValue) : IAuthorizationRequirement
{
    public string ClaimValue { get; } = claimValue;
}
