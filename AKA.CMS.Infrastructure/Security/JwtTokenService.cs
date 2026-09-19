using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using Microsoft.IdentityModel.Tokens;

namespace AKA.CMS.Infrastructure.Security;

public sealed class JwtTokenService(JwtOptions options) : IJwtTokenService
{
    public const string PermissionClaimType = "cms_permission";

    public string CreateAccessToken(User user, IReadOnlyList<string> permissionClaims)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
            new(JwtRegisteredClaimNames.UniqueName, user.Username),
            new("admin", user.IsAdmin ? "1" : "0")
        };
        claims.AddRange(user.Roles.Select(r => new Claim(ClaimTypes.Role, r)));
        claims.AddRange(permissionClaims.Select(p => new Claim(PermissionClaimType, p)));

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(options.SigningKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: options.Issuer,
            audience: options.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(options.AccessTokenMinutes),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
