using AKA.CMS.Infrastructure.Security;
using Microsoft.AspNetCore.Authorization;

namespace AKA.CMS.API.Auth;

public sealed class PermissionAuthorizationHandler : AuthorizationHandler<PermissionAuthorizationRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        PermissionAuthorizationRequirement requirement)
    {
        if (context.User.HasClaim(JwtTokenService.PermissionClaimType, requirement.ClaimValue))
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
