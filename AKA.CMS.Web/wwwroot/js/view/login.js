/* Login — posts credentials as JSON through the global cmsAjax helper,
   DIRECTLY to the Web API (POST /api/auth/login). The returned JWT pair is
   kept in browser storage; cmsAjax attaches it as a Bearer token on every
   later API call. Razor never sees the credentials. */
$(function () {
    // Already signed in? Skip the login page.
    if (window.cmsAuth && window.cmsAuth.isLoggedIn()) {
        window.location.href = '/Users';
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
                data: { username: username, password: password },
                fallbackMsg: 'Sign in failed.',
                success: function (resp) {
                    window.cmsAuth.save(resp, remember);
                    window.location.href = '/Users';
                },
                error: function () {
                    $btn.prop('disabled', false).text('Sign in');
                    return false; // keep the default error toast
                }
            });
        }
    });
});
