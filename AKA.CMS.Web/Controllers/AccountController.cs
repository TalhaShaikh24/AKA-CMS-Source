using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Security;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Web login/logout. Credentials are validated through the shared
/// <see cref="IAuthService"/> (same users, same password hashes as the API);
/// the API itself is never called over HTTP from here.</summary>
public sealed class AccountController(IAuthService authService) : Controller
{
    public sealed record WebLoginRequest(string Username, string Password, bool RememberMe);

    [HttpGet]
    [AllowAnonymous]
    public IActionResult Login(string? returnUrl = null)
    {
        if (User.Identity?.IsAuthenticated == true)
            return RedirectToAction("Index", "Users");
        ViewData["ReturnUrl"] = returnUrl;
        return View();
    }

    /// <summary>Validates credentials and issues the auth cookie.
    /// Called by the login page through the global cmsAjax helper.</summary>
    [HttpPost]
    [AllowAnonymous]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login([FromBody] WebLoginRequest request)
    {
        try
        {
            var response = await authService.LoginAsync(
                new LoginRequest(request.Username?.Trim() ?? string.Empty, request.Password ?? string.Empty));

            var identity = BuildIdentity(response);
            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                new ClaimsPrincipal(identity),
                new AuthenticationProperties
                {
                    IsPersistent = request.RememberMe,
                    ExpiresUtc = request.RememberMe
                        ? DateTimeOffset.UtcNow.AddDays(7)
                        : DateTimeOffset.UtcNow.AddHours(8)
                });

            return Json(new { ok = true, redirectUrl = Url.Action("Index", "Users") });
        }
        catch (UnauthorizedException)
        {
            Response.StatusCode = StatusCodes.Status401Unauthorized;
            return Json(new { ok = false, message = "Invalid username or password." });
        }
        catch (FluentValidation.ValidationException ex)
        {
            Response.StatusCode = StatusCodes.Status400BadRequest;
            return Json(new { ok = false, message = ex.Message });
        }
    }

    [HttpPost]
    [Authorize]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Login));
    }

    /// <summary>Copies the user id, username, roles and cms_permission claims
    /// from the freshly issued JWT into the cookie identity, so the shared
    /// ICurrentUser and permission policies work unchanged.</summary>
    private static ClaimsIdentity BuildIdentity(LoginResponse response)
    {
        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(response.AccessToken);
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, response.User.UserId.ToString()),
            new(ClaimTypes.Name, response.User.Username),
            new(JwtRegisteredClaimNames.UniqueName, response.User.Username)
        };
        claims.AddRange(response.User.Roles.Select(r => new Claim(ClaimTypes.Role, r)));
        claims.AddRange(jwt.Claims
            .Where(c => c.Type == JwtTokenService.PermissionClaimType)
            .Select(c => new Claim(JwtTokenService.PermissionClaimType, c.Value)));
        return new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
    }
}
