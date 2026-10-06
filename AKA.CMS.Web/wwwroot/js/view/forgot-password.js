/* ==========================================================================
   CMS · Forgot Password — js/view/forgot-password.js
   API: POST /api/auth/forgot-password { email }  (anonymous)
   The API never reveals whether the email belongs to an account, so we
   always show the same confirmation afterwards.
   ========================================================================== */
$(function () {
  'use strict';

  // Already signed in? No need for a reset link.
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
        url: '/api/auth/forgot-password',
        method: 'POST',
        json: true,
        auth: false,
        data: { email: email },
        fallbackMsg: 'Could not send the reset link.',
        success: function (resp) {
          $('#forgotForm').prop('hidden', true);
          if (resp && resp.message) $('#fpDoneMsg').text(resp.message);
          $('#fpDone').prop('hidden', false);
          CMS.toast('Reset link sent. Check your inbox.', 'success');
        },
        error: function () {
          $btn.prop('disabled', false).text('Send reset link');
          return false; // keep the default error toast
        }
      });
    }
  });
});
