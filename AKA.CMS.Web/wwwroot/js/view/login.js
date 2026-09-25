/* Login — posts credentials as JSON through the global cmsAjax helper.
   The server validates via the shared IAuthService and issues an auth cookie. */
$(function () {
  $('#loginForm').cmsValidate({
    onValid: function () {
      cmsAjax({
        url: '/Account/Login',
        method: 'POST',
        json: true,
        data: {
          username: $.trim($('#loginUser').val()),
          password: $('#loginPass').val(),
          rememberMe: $('#rememberMe').is(':checked')
        },
        success: function (res) {
          CMS.toast('Welcome back! Signed in successfully.', 'success');
          setTimeout(function () { location.href = (res && res.redirectUrl) || '/Users'; }, 700);
        },
        error: function (xhr) {
          if (xhr.status === 401) {
            CMS.toast('Invalid username or password.', 'error');
            return true;
          }
          return false;
        }
      });
    }
  });
});
