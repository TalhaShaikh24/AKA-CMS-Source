/* ==========================================================================
   CMS · Reset Password — js/view/reset-password.js
   Two modes (anonymous):
     token mode: ?token=...  → POST /api/auth/reset-password { token, newPassword }
     otp mode:   ?mode=otp&email=... → POST /api/auth/reset-password-otp
                 { email, otp, newPassword }  (mobile design: Reset Pass)
   The OTP itself travels in sessionStorage (set by otp.js), never in the URL.
   On success all existing sessions are revoked server-side, so we send the
   user back to sign in.
   ========================================================================== */
$(function () {
  'use strict';

  var qs = new URLSearchParams(window.location.search);
  var mode = qs.get('mode');
  var token = qs.get('token');
  var email = qs.get('email') || '';
  var otp = null;
  try { otp = sessionStorage.getItem('cms_otp'); } catch (err) { /* private mode */ }

  var isOtpMode = mode === 'otp';
  if (isOtpMode && (!email || !/^\d{4}$/.test(otp || ''))) {
    $('#rpInvalid').prop('hidden', false);
    return;
  }
  if (!isOtpMode && !token) {
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

      var payload, url, fallback;
      if (isOtpMode) {
        url = '/api/auth/reset-password-otp';
        payload = { email: email, otp: otp, newPassword: p1 };
        fallback = 'Could not reset the password. The code may have expired.';
      } else {
        url = '/api/auth/reset-password';
        payload = { token: token, newPassword: p1 };
        fallback = 'Could not reset the password. The link may have expired.';
      }

      cmsAjax({
        url: url,
        method: 'POST',
        json: true,
        auth: false,
        data: payload,
        fallbackMsg: fallback,
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
