namespace AKA.CMS.Application.DTOs;

/// <summary>Login credentials. RememberMe extends the refresh-token lifetime
/// (Jwt:RememberMeRefreshTokenDays instead of Jwt:RefreshTokenDays).</summary>
public sealed record LoginRequest(string Username, string Password, bool RememberMe = false);
