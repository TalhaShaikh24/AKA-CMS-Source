using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using AKA.CMS.Infrastructure.Security;

namespace AKA.CMS.API.Auth;

public interface ICurrentUser
{
    int UserId { get; }
    string Username { get; }
    bool HasPermission(string permissionName);
}

public sealed class HttpContextCurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    // The JWT handler maps "sub" to ClaimTypes.NameIdentifier by default;
    // accept both so the user id resolves regardless of inbound mapping.
    public int UserId => int.Parse(
        accessor.HttpContext?.User.FindFirstValue(JwtRegisteredClaimNames.Sub)
        ?? accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? "0");

    public string Username =>
        accessor.HttpContext?.User.FindFirstValue(JwtRegisteredClaimNames.UniqueName) ?? string.Empty;

    public bool HasPermission(string permissionName) =>
        accessor.HttpContext?.User.HasClaim(JwtTokenService.PermissionClaimType, permissionName) == true;
}
