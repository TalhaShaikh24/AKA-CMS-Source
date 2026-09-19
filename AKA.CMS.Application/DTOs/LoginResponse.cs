
namespace AKA.CMS.Application.DTOs;

public sealed record LoginResponse(
    string AccessToken,
    string RefreshToken,
    DateTime ExpiresAt,
    AuthUserDto User);
