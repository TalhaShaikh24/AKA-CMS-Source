/* ==========================================================================
   CMS · Reset Password — js/view/reset-password.js
   Final step of the forgot-password flow (anonymous):
     ?email=... + the OTP verified on the OTP screen (kept in
     sessionStorage by otp.js, never in the URL)
     → POST /api/auth/reset-password { email, otp, newPassword }
   The reset call re-verifies and consumes the code server-side.
   On success all existing sessions are revoked server-side, so we send
   the user back to sign in.
   ========================================================================== */
$(function () {
  'use strict';

  var email = new URLSearchParams(window.location.search).get('email') || '';
  var otp = null;
  try { otp = sessionStorage.getItem('cms_otp'); } catch (err) { /* private mode */ }

  if (!email || !/^\d{4}$/.test(otp || '')) {
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
        data: { email: email, otp: otp, newPassword: p1 },
        fallbackMsg: 'Could not reset the password. The code may have expired.',
        success: function () {
          try { sessionStorage.removeItem('cms_otp'); } catch (err) { /* private mode */ }
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
