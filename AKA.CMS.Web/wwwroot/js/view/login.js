/* Login — posts credentials as JSON through the global cmsAjax helper,
   DIRECTLY to the Web API (POST /api/auth/login). The returned JWT pair is
   kept in browser storage; cmsAjax attaches it as a Bearer token on every
   later API call. Razor never sees the credentials. */
$(function () {
    function returnUrl() {
        var ret = new URLSearchParams(window.location.search).get('returnUrl');
        // Only allow same-origin relative redirects.
        return ret && ret.charAt(0) === '/' && ret.charAt(1) !== '/' ? ret : '';
    }

    // Already signed in? Skip the login page.
    if (window.cmsAuth && window.cmsAuth.isSessionValid()) {
        window.location.href = returnUrl() || '/Dashboard';
        return;
    }

    $('#loginForm').cmsValidate({
        onValid: function () {
            var username = $.trim($('#loginUser').val());
            var password = $('#loginPass').val();
            var remember = $('#rememberMe').is(':checked');
            var $btn = $('#loginForm').find('button[type="submit"]');

            $btn.prop('disabled', true).text('Signing in…');

            cmsAjax({
                url: '/api/auth/login',
                method: 'POST',
                json: true,
                auth: false, // no token yet
                data: { username: username, password: password, rememberMe: remember },
                fallbackMsg: 'Sign in failed.',
                success: function (resp) {
                    window.cmsAuth.save(resp, remember);
                    window.location.href = returnUrl() || '/Dashboard';
                },
                error: function () {
                    $btn.prop('disabled', false).text('Sign in');
                    return false; // keep the default error toast
                }
            });
        }
    });
});
