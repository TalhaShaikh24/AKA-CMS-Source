/* ==========================================================================
   CMS · Forgot Password (OTP flow) — js/view/forgot-password.js
   API: POST /api/auth/forgot-password-otp { email }  (anonymous)
   The API never reveals whether the email belongs to an account; on success
   we move to the OTP screen (mobile design: Forget Pass -> OTP).
   ========================================================================== */
$(function () {
  'use strict';

  // Already signed in? No need for a reset.
  if (window.cmsAuth && window.cmsAuth.isSessionValid()) {
    window.location.href = '/Dashboard';
    return;
  }

  $('#forgotForm').cmsValidate({
    onValid: function () {
      var email = $.trim($('#fpEmail').val());
      var $btn = $('#forgotForm').find('button[type="submit"]');
      $btn.prop('disabled', true).text('Sending…');

      cmsAjax({
        url: '/api/auth/forgot-password-otp',
        method: 'POST',
        json: true,
        auth: false,
        data: { email: email },
        fallbackMsg: 'Could not send the verification code.',
        success: function () {
          window.location.href = '/Account/Otp?email=' + encodeURIComponent(email);
        },
        error: function () {
          $btn.prop('disabled', false).text('Continue');
          return false; // keep the default error toast
        }
      });
    }
  });
});
