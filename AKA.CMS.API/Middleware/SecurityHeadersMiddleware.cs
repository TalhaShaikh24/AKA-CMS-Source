namespace AKA.CMS.API.Middleware;

/// <summary>
/// Adds baseline security headers to every response. HSTS is only sent
/// outside Development (local dev typically runs over plain HTTP).
/// </summary>
public sealed class SecurityHeadersMiddleware(RequestDelegate next, IWebHostEnvironment environment)
{
    public async Task InvokeAsync(HttpContext context)
    {
        context.Response.Headers["X-Content-Type-Options"] = "nosniff";
        context.Response.Headers["X-Frame-Options"] = "DENY";
        context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
        context.Response.Headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";

        if (!environment.IsDevelopment())
        {
            // 1 year, include sub-domains. Only meaningful over HTTPS.
            context.Response.Headers["Strict-Transport-Security"] =
                "max-age=31536000; includeSubDomains";
        }

        await next(context);
    }
}
