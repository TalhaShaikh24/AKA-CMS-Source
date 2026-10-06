/* ==========================================================================
   CMS · Reset Password — js/view/reset-password.js
   API: POST /api/auth/reset-password { token, newPassword }  (anonymous)
   The token arrives as ?token=... in the link the API e-mails to the user.
   On success all existing sessions are revoked server-side, so we send the
   user back to sign in.
   ========================================================================== */
$(function () {
  'use strict';

  var token = new URLSearchParams(window.location.search).get('token');
  if (!token) {
    $('#rpInvalid').prop('hidden', false);
    return;
  }
  $('#resetForm').prop('hidden', false);

  $('#resetForm').cmsValidate({
    onValid: function () {
      var p1 = $('#rpPass').val();
      var p2 = $('#rpPass2').val();
      if (p1 !== p2) {
        $('#rpPass2').addClass('invalid')
          .closest('.field').find('.field-error').text('Passwords do not match.');
        return;
      }
      var $btn = $('#resetForm').find('button[type="submit"]');
      $btn.prop('disabled', true).text('Saving…');

      cmsAjax({
        url: '/api/auth/reset-password',
        method: 'POST',
        json: true,
        auth: false,
        data: { token: token, newPassword: p1 },
        fallbackMsg: 'Could not reset the password. The link may have expired.',
        success: function () {
          CMS.toast('Password changed. Please sign in again.', 'success');
          setTimeout(function () { window.location.href = '/Account/Login'; }, 900);
        },
        error: function () {
          $btn.prop('disabled', false).text('Set new password');
          return false; // keep the default error toast
        }
      });
    }
  });
});
