/* ==========================================================================
   CMS · auth-guard.js
   --------------------------------------------------------------------------
   Page-level access control for the Razor shell. The real security boundary
   is the Web API (401/403 on every call); this guard keeps the UI honest:
     1. No valid JWT session  → bounce to /Account/Login?returnUrl=...
     2. Page needs a permission (body[data-required-permission]) and the
        user lacks it → bounce to /Dashboard?denied=... with an error toast.
     3. Sidebar links carrying data-permission are hidden when the user
        lacks that permission; empty nav sections are hidden too.
   Permissions come from the JWT's "cms_permission" claims, which the API
   builds from the database (USER_ROLE / ROLEACTIONMAPPING / AllCONTROLLERS)
   at login — nothing is hardcoded here.
   This file is only loaded by the shared _Layout; the auth pages
   (Login / ForgotPassword / ResetPassword) use Layout = null and skip it.
   ========================================================================== */
(function () {
    'use strict';

    var auth = window.cmsAuth;
    if (!auth) return; // ajax.js failed to load; nothing to guard with

    // 1. Must be signed in (token present and not expired).
    if (!auth.requireAuth()) return;

    // 2. Page-level permission, declared by the view as
    //    ViewData["RequiredPermission"] -> body[data-required-permission].
    var required = document.body.getAttribute('data-required-permission');
    if (required && !auth.requirePermission(required)) return;

    // 4. Sidebar: hide links the user may not use.
    var links = document.querySelectorAll('.nav a[data-permission]');
    for (var i = 0; i < links.length; i++) {
        if (!auth.hasPermission(links[i].getAttribute('data-permission'))) {
            links[i].style.display = 'none';
        }
    }
    // Hide section labels left without any visible link.
    var labels = document.querySelectorAll('.nav .nav-label');
    for (var j = 0; j < labels.length; j++) {
        var el = labels[j].nextElementSibling;
        var anyVisible = false;
        while (el && !el.classList.contains('nav-label')) {
            if (el.tagName === 'A' && el.style.display !== 'none') { anyVisible = true; break; }
            el = el.nextElementSibling;
        }
        if (!anyVisible) labels[j].style.display = 'none';
    }

    // 3. Access-denied feedback after a requirePermission() bounce.
    var denied = new URLSearchParams(window.location.search).get('denied');
    if (denied && window.CMS && window.CMS.toast) {
        window.CMS.toast('You do not have permission to access that page.', 'error');
        // Clean the URL so a refresh does not repeat the toast.
        var url = window.location.pathname + window.location.search.replace(/([?&])denied=[^&]*/, '$1').replace(/[?&]$/, '');
        window.history.replaceState(null, '', url || window.location.pathname);
    }
})();
