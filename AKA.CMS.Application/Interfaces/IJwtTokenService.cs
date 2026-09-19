using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IJwtTokenService
{
    string CreateAccessToken(User user, IReadOnlyList<string> permissionClaims);
}
