/* ==========================================================================
   CMS · Edit Profile — js/view/profile.js
   API-wired:
     GET /api/users/me  → load the signed-in user's profile
     PUT /api/users/me  → update e-mail and/or password (self-service;
                          no admin permission required)
   ========================================================================== */
$(function () {
  'use strict';

  function markInvalid($f, msg) {
    $f.addClass('invalid');
    $f.closest('.field').find('.field-error').text(msg || 'This field is invalid.');
  }
  function clearInvalid() {
    $('#profileForm').find('.invalid').removeClass('invalid');
    $('#profileForm').find('.field-error').text('');
  }

  // Load current profile.
  CMS.loader(true);
  cmsAjax({
    url: '/api/users/me',
    method: 'GET',
    fallbackMsg: 'Could not load your profile.',
    success: function (u) {
      CMS.loader(false);
      $('#pfUsername').val(u.username || '');
      $('#pfEmail').val(u.email || '');
    },
    error: function () { CMS.loader(false); }
  });

  $('#profileForm').cmsValidate({
    onValid: function () {
      clearInvalid();
      var email = $.trim($('#pfEmail').val());
      var p1 = $('#pfPass').val();
      var p2 = $('#pfPass2').val();

      if (p1 || p2) {
        if (p1.length < 8) {
          markInvalid($('#pfPass'), 'Password must be at least 8 characters.');
          return;
        }
        if (p1 !== p2) {
          markInvalid($('#pfPass2'), 'Passwords do not match.');
          return;
        }
      }

      var $btn = $('#profileForm').find('button[type="submit"]');
      $btn.prop('disabled', true).text('Saving…');

      cmsAjax({
        url: '/api/users/me',
        method: 'PUT',
        json: true,
        data: { email: email || null, newPassword: p1 || null },
        fallbackMsg: 'Could not update your profile.',
        success: function () {
          $btn.prop('disabled', false).text('Save Changes');
          $('#pfPass').val('');
          $('#pfPass2').val('');
          CMS.toast('Profile updated.', 'success');
        },
        error: function () {
          $btn.prop('disabled', false).text('Save Changes');
          return false; // keep the default error toast
        }
      });
    }
  });
});
