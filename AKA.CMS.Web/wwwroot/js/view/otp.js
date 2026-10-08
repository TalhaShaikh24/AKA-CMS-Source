/* ==========================================================================
   CMS · OTP verification — js/view/otp.js
   Mobile design: Enter OTP -> Continue -> Reset Pass.
   The 4-digit code is kept in sessionStorage (never in the URL) and carried
   to the Reset Password screen, which posts it together with the new password.
   API: POST /api/auth/forgot-password-otp { email }  (resend, anonymous)
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
    try { sessionStorage.setItem('cms_otp', c); } catch (err) { /* private mode */ }
    window.location.href = '/Account/ResetPassword?mode=otp&email=' + encodeURIComponent(email);
  });

  $('#resendOtp').on('click', function (e) {
    e.preventDefault();
    var $link = $(this);
    cmsAjax({
      url: '/api/auth/forgot-password-otp',
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
