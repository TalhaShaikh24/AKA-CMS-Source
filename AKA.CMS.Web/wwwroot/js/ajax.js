/* ==========================================================================
   CMS · Integrated Mental Health Programme — js/ajax.js
   --------------------------------------------------------------------------
   Global AJAX helper. Every call goes DIRECTLY to the Web API — Razor never
   touches the backend. The API base URL is rendered into the page by the
   shared layout as window.CMS_API_BASE_URL (from appsettings "ApiBaseUrl");
   any url starting with /api/ is prefixed with it.

   Usage (same contract as the original template helper):
     cmsAjax({
       url: '/api/users', method: 'GET',
       fallbackMsg: 'Could not load users.',
       success: function (res) { render(res); },
       error: function (xhr) { return true; }   // truthy = suppress toast
     });

     cmsAjax({
       url: '/api/auth/login', method: 'POST', json: true, auth: false,
       data: { username: u, password: p },
       success: function (resp) { window.cmsAuth.save(resp, remember); }
     });

   Options:
     url, method ('GET'), data, timeout
     json        : opt-in JSON body instead of form-urlencoded (default false)
     auth        : attach the JWT bearer token (default true; pass false for
                   /api/auth/login and /api/auth/refresh)
     fallbackMsg : toast text when the call fails and error() doesn't
                   suppress it
     success(res): called with the parsed response body
     error(xhr)  : called on failure; return a truthy value to suppress the
                   default error toast

   The access token is attached as an Authorization: Bearer header. On a 401
   the stored refresh token is exchanged once for a new pair and the request
   is retried; when that fails the session is cleared and the login page is
   shown.
   ========================================================================== */
(function (global, $) {
    'use strict';

    var LOGIN_PAGE = '/Account/Login';

    function apiUrl(url) {
        if (!url || /^https?:\/\//i.test(url) || url.charAt(0) !== '/') return url;
        var base = (global.CMS_API_BASE_URL || '').replace(/\/+$/, '');
        return url.indexOf('/api/') === 0 && base ? base + url : url;
    }

    /* ---------------- token storage ---------------- */
    function targetStore(remember) {
        return remember ? global.localStorage : global.sessionStorage;
    }

    function readTokens() {
        var access = global.localStorage.getItem('cms_access_token')
            || global.sessionStorage.getItem('cms_access_token');
        var refresh = global.localStorage.getItem('cms_refresh_token')
            || global.sessionStorage.getItem('cms_refresh_token');
        return access ? { accessToken: access, refreshToken: refresh } : null;
    }

    global.cmsAuth = {
        getTokens: readTokens,
        isLoggedIn: function () { return !!readTokens(); },
        getUser: function () {
            var raw = global.localStorage.getItem('cms_user')
                || global.sessionStorage.getItem('cms_user');
            try { return raw ? JSON.parse(raw) : null; } catch (e) { return null; }
        },
        save: function (loginResponse, remember) {
            var s = targetStore(!!remember);
            s.setItem('cms_access_token', loginResponse.accessToken);
            s.setItem('cms_refresh_token', loginResponse.refreshToken);
            s.setItem('cms_user', JSON.stringify(loginResponse.user || {}));
            s.setItem('cms_remember', remember ? '1' : '0');
        },
        clear: function () {
            [global.localStorage, global.sessionStorage].forEach(function (s) {
                s.removeItem('cms_access_token');
                s.removeItem('cms_refresh_token');
                s.removeItem('cms_user');
                s.removeItem('cms_remember');
            });
        },
        rememberMe: function () {
            return (global.localStorage.getItem('cms_remember')
                || global.sessionStorage.getItem('cms_remember')) === '1';
        },
        logout: function () {
            var tokens = readTokens();
            function finish() {
                global.cmsAuth.clear();
                global.location.href = LOGIN_PAGE;
            }
            if (tokens && tokens.refreshToken) {
                // Best-effort server-side revocation; never blocks the redirect.
                try {
                    cmsAjax({
                        url: '/api/auth/logout', method: 'POST', json: true,
                        data: { refreshToken: tokens.refreshToken },
                        success: finish,
                        error: function () { finish(); return true; }
                    });
                } catch (e) { finish(); }
            } else {
                finish();
            }
        }
    };

    /* ---------------- refresh handling ---------------- */
    var refreshPromise = null;

    function refreshTokens() {
        if (!refreshPromise) {
            var tokens = readTokens();
            if (!tokens || !tokens.refreshToken) {
                refreshPromise = $.Deferred().reject().promise();
            } else {
                refreshPromise = $.ajax({
                    url: apiUrl('/api/auth/refresh'),
                    method: 'POST',
                    contentType: 'application/json; charset=utf-8',
                    dataType: 'json',
                    data: JSON.stringify({ refreshToken: tokens.refreshToken })
                }).then(function (resp) {
                    global.cmsAuth.save(resp, global.cmsAuth.rememberMe());
                    return resp;
                });
                refreshPromise.always(function () { refreshPromise = null; });
            }
        }
        return refreshPromise;
    }

    /* ---------------- the global helper ---------------- */
    function cmsAjax(options) {
        options = options || {};
        var method = (options.method || 'GET').toUpperCase();
        var useJson = !!options.json;
        var useAuth = options.auth !== false;
        var data = options.data;

        var ajaxOptions = {
            url: apiUrl(options.url),
            method: method,
            dataType: 'json'
        };

        function applyAuthHeader() {
            var tokens = useAuth ? readTokens() : null;
            ajaxOptions.headers = tokens
                ? { 'Authorization': 'Bearer ' + tokens.accessToken }
                : {};
        }
        applyAuthHeader();

        if (data !== undefined && data !== null && !(data instanceof FormData)) {
            if (useJson || (method !== 'GET' && method !== 'HEAD')) {
                ajaxOptions.contentType = 'application/json; charset=utf-8';
                ajaxOptions.data = JSON.stringify(data);
            } else {
                ajaxOptions.data = data;
            }
        } else if (data instanceof FormData) {
            ajaxOptions.data = data;
            ajaxOptions.processData = false;
            ajaxOptions.contentType = false;
        }

        if (options.timeout) ajaxOptions.timeout = options.timeout;

        function handleFailure(xhr) {
            var suppressed = false;
            try {
                if (typeof options.error === 'function') suppressed = !!options.error(xhr);
            } catch (e) { /* caller error must not break the flow */ }
            if (!suppressed && window.CMS && typeof window.CMS.toast === 'function') {
                window.CMS.toast(global.cmsErrorMessage(xhr, options.fallbackMsg), 'error');
            }
        }

        var retried = false;
        function attempt() {
            return $.ajax(ajaxOptions).then(
                function (res) {
                    if (typeof options.success === 'function') options.success(res);
                    return res;
                },
                function (xhr) {
                    if (xhr.status === 401 && useAuth && !retried) {
                        retried = true;
                        return refreshTokens().then(
                            function () {
                                applyAuthHeader();
                                return attempt();
                            },
                            function () {
                                global.cmsAuth.clear();
                                handleFailure(xhr);
                                if (global.location.pathname !== LOGIN_PAGE) {
                                    global.location.href = LOGIN_PAGE;
                                }
                                return $.Deferred().reject(xhr).promise();
                            });
                    }
                    handleFailure(xhr);
                    return $.Deferred().reject(xhr).promise();
                });
        }
        return attempt();
    }

    global.cmsAjax = cmsAjax;

    /* Friendly message for API problem-details / validation responses. */
    global.cmsErrorMessage = function (xhr, fallback) {
        fallback = fallback || 'Request failed. Please try again.';
        if (!xhr) return fallback;
        try {
            var body = xhr.responseJSON || (xhr.responseText ? JSON.parse(xhr.responseText) : null);
            if (body) {
                if (body.detail) return body.detail;
                if (body.title) return body.title;
                if (body.message) return body.message;
                if (body.errors) {
                    var first = Object.keys(body.errors)[0];
                    var msgs = body.errors[first];
                    if (msgs && msgs.length) return msgs[0];
                }
            }
        } catch (e) { /* fall through */ }
        if (xhr.status === 0) return 'Cannot reach the API. Is it running?';
        if (xhr.status === 401) return 'Your session has expired. Please log in again.';
        if (xhr.status === 403) return 'You do not have permission for this action.';
        return fallback;
    };
})(window, jQuery);
