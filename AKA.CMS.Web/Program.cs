using System.Text.Json;
using AKA.CMS.API.Auth;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Validators;
using AKA.CMS.Infrastructure;
using FluentValidation;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;

var builder = WebApplication.CreateBuilder(args);

// Same data layer as the API: Dapper + stored procedures, no raw SQL in this project.
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddValidatorsFromAssemblyContaining<LoginRequestValidator>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpContextCurrentUser>();

// Cookie authentication for the web UI (the mobile/API surface keeps using JWT).
builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.AccessDeniedPath = "/Account/Login";
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;
        options.Cookie.Name = "aka_cms_web";
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        // AJAX (cmsAjax) calls get a 401 instead of a login-page redirect.
        options.Events.OnRedirectToLogin = context =>
        {
            if (IsAjax(context.Request))
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                return Task.CompletedTask;
            }
            context.Response.Redirect(context.RedirectUri);
            return Task.CompletedTask;
        };
        options.Events.OnRedirectToAccessDenied = context =>
        {
            if (IsAjax(context.Request))
            {
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                return Task.CompletedTask;
            }
            context.Response.Redirect(context.RedirectUri);
            return Task.CompletedTask;
        };
    });

// Same database-driven permission policies as the API (no hardcoded roles/permissions).
builder.Services.AddSingleton<PermissionCatalog>();
builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();
builder.Services.AddScoped<IAuthorizationHandler, PermissionAuthorizationHandler>();
builder.Services.AddAuthorization();

builder.Services.AddAntiforgery(options => options.HeaderName = "RequestVerificationToken");
builder.Services.AddControllersWithViews()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DictionaryKeyPolicy = JsonNamingPolicy.CamelCase;
    });

var app = builder.Build();

// Load the permission catalog from AllCONTROLLERS (same as the API startup).
using (var scope = app.Services.CreateScope())
{
    var authRepository = scope.ServiceProvider.GetRequiredService<IAuthRepository>();
    var catalog = scope.ServiceProvider.GetRequiredService<PermissionCatalog>();
    var permissions = await authRepository.GetAllPermissionsAsync();
    catalog.Load(permissions.Select(p => p.PolicyName));
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();

static bool IsAjax(HttpRequest request) =>
    string.Equals(request.Headers.XRequestedWith, "XMLHttpRequest", StringComparison.OrdinalIgnoreCase)
    || request.Headers.Accept.ToString().Contains("application/json", StringComparison.OrdinalIgnoreCase);
