/// <summary>
/// AKA.CMS.Web — thin MVC shell that serves the Razor views (login, users,
/// roles &amp; permissions). It holds no connection string and calls no backend
/// services: the browser talks to the Web API directly through the global
/// cmsAjax helper (see wwwroot/js/ajax.js), which attaches the JWT bearer
/// token issued by POST /api/auth/login.
/// </summary>
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
