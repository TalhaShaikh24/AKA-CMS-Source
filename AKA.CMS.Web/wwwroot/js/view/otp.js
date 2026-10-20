/* ==========================================================================
   CMS · OTP verification — js/view/otp.js
   Enter OTP -> the code is VERIFIED against the database
   (POST /api/auth/verify-reset-otp) -> only then the Reset Password
   screen opens. An invalid code shows the error right here.
   The verified code is kept in sessionStorage (never in the URL) and
   carried to the Reset Password screen, which posts it together with
   the new password (the reset call consumes it).
   API: POST /api/auth/forgot-password { email }  (resend, anonymous)
   ========================================================================== */
$(function () {
  'use strict';

  if (window.cmsAuth && window.cmsAuth.isSessionValid()) {
    window.location.href = '/Dashboard';
    return;
  }

  var email = new URLSearchParams(window.location.search).get('email') || '';
  if (!email) {
    window.location.href = '/Account/ForgotPassword';
    return;
  }
  $('#otpEmailEcho').text(email);

  var $boxes = $('#otpRow .otp-box');
  $boxes.first().focus();

  $boxes.on('input', function () {
    var $b = $(this);
    $b.val($b.val().replace(/\D/g, '').slice(0, 1));
    $b.toggleClass('filled', !!$b.val());
    $('#otpError').text('');
    if ($b.val() && $b.next('.otp-box').length) $b.next('.otp-box').focus();
  });

  $boxes.on('keydown', function (e) {
    if (e.key === 'Backspace' && !$(this).val() && $(this).prev('.otp-box').length) {
      $(this).prev('.otp-box').focus().val('').removeClass('filled');
    }
  });

  $boxes.on('paste', function (e) {
    var text = ((e.originalEvent.clipboardData || window.clipboardData).getData('text') || '').replace(/\D/g, '').slice(0, 4);
    if (!text) return;
    e.preventDefault();
    $boxes.each(function (i) {
      $(this).val(text[i] || '').toggleClass('filled', !!text[i]);
    });
    $boxes.eq(Math.min(text.length, 3)).focus();
  });

  function code() {
    var c = '';
    $boxes.each(function () { c += $(this).val(); });
    return c;
  }

  $('#otpForm').on('submit', function (e) {
    e.preventDefault();
    var c = code();
    if (!/^\d{4}$/.test(c)) {
      $('#otpError').text('Please enter the 4-digit code.');
      $boxes.first().focus();
      return;
    }
    var $btn = $('#otpForm').find('button[type="submit"]');
    $btn.prop('disabled', true).text('Verifying…');
    cmsAjax({
      url: '/api/auth/verify-reset-otp',
      method: 'POST',
      json: true,
      auth: false,
      data: { email: email, otp: c },
      fallbackMsg: 'Could not verify the code.',
      success: function () {
        try { sessionStorage.setItem('cms_otp', c); } catch (err) { /* private mode */ }
        window.location.href = '/Account/ResetPassword?email=' + encodeURIComponent(email);
      },
      error: function (xhr) {
        $btn.prop('disabled', false).text('Continue');
        var msg = 'The verification code is invalid or has expired.';
        try {
          var body = JSON.parse(xhr.responseText);
          if (body && (body.detail || body.title)) msg = body.detail || body.title;
        } catch (err) { /* keep default message */ }
        $('#otpError').text(msg);
        return true; // error shown inline — suppress the toast
      }
    });
  });

  $('#resendOtp').on('click', function (e) {
    e.preventDefault();
    var $link = $(this);
    cmsAjax({
      url: '/api/auth/forgot-password',
      method: 'POST',
      json: true,
      auth: false,
      data: { email: email },
      fallbackMsg: 'Could not resend the code.',
      success: function () {
        CMS.toast('A new code has been sent.', 'success');
        $boxes.val('').removeClass('filled').first().focus();
      },
      error: function () { return false; }
    });
    $link.css('pointer-events', 'none').css('opacity', '.5');
    setTimeout(function () { $link.css('pointer-events', '').css('opacity', ''); }, 30000);
  });
});
