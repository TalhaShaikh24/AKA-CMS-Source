using System.Text;
using System.Threading.RateLimiting;
using AKA.CMS.API.Auth;
using AKA.CMS.API.Middleware;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Validators;
using AKA.CMS.Infrastructure;
using FluentValidation;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateLogger();
builder.Host.UseSerilog();

builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddValidatorsFromAssemblyContaining<LoginRequestValidator>();
builder.Services.Configure<FileStorageOptions>(
    builder.Configuration.GetSection(FileStorageOptions.SectionName));
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpContextCurrentUser>();

var jwt = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>()
    ?? throw new InvalidOperationException("Jwt settings are missing.");

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });

builder.Services.AddSingleton<PermissionCatalog>();
builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();
builder.Services.AddScoped<IAuthorizationHandler, PermissionAuthorizationHandler>();
builder.Services.AddAuthorization();

// CORS for the web UI (AKA.CMS.Web): the browser calls this API directly
// through the cmsAjax helper, so the web origin must be allowed here.
// Configure via "Cors:AllowedOrigins" in appsettings.
var corsOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? [];
builder.Services.AddCors(options =>
    options.AddPolicy("WebApp", policy => policy
        .WithOrigins(corsOrigins)
        .AllowAnyHeader()
        .AllowAnyMethod()));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// PROVISIONAL (Sprint 10): fixed-window rate limit for the auth endpoints
// (login / refresh / logout) — 60 attempts per minute per client IP.
// Rationale: 10/min (the usual production starting point) throttles the
// automated regression suite, which legitimately bursts logins from one IP.
// 60/min still blunts naive credential-stuffing while letting the suite and
// normal client bursts through. Tighten before production with per-account
// limits, sliding windows, and a CAPTCHA/notify step after repeated failures
// — tracked as an open client-confirmation item.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("auth", limiterOptions =>
    {
        limiterOptions.PermitLimit = 60;
        limiterOptions.Window = TimeSpan.FromMinutes(1);
        limiterOptions.QueueLimit = 0;
        limiterOptions.AutoReplenishment = true;
    });
});

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "AKA-CMS API", Version = "v1" });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Enter the JWT access token."
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },
            Array.Empty<string>()
        }
    });

    // XML doc comments from controllers/services feed the Swagger UI descriptions.
    var xmlPath = Path.Combine(AppContext.BaseDirectory, "AKA.CMS.API.xml");
    if (File.Exists(xmlPath))
        options.IncludeXmlComments(xmlPath);
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var authRepository = scope.ServiceProvider.GetRequiredService<IAuthRepository>();
    var catalog = scope.ServiceProvider.GetRequiredService<PermissionCatalog>();
    var permissions = await authRepository.GetAllPermissionsAsync();
    catalog.Load(permissions.Select(p => p.PolicyName));
    Log.Information("Loaded {Count} permission policies from AllCONTROLLERS", permissions.Count);
}

app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseMiddleware<CorrelationIdMiddleware>();
app.UseMiddleware<SecurityHeadersMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Swagger visibility is driven by appsettings ("Swagger" section), not by
// environment: the API's default view can be the Swagger UI.
var swaggerEnabled = builder.Configuration.GetValue<bool>("Swagger:Enabled");
var swaggerAsDefault = builder.Configuration.GetValue<bool>("Swagger:ServeAsDefaultView");
if (swaggerEnabled || swaggerAsDefault)
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
if (swaggerAsDefault)
{
    app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();
}

app.UseRateLimiter();
app.UseCors("WebApp");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
