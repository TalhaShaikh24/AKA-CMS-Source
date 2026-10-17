/* Settings — wired to /api/settings (profile, notifications, system). */
$(function () {

  function initSelect2($el, opts) {
    if (!$el.length || !$.fn.select2 || $el.data('select2')) return;
    $el.select2($.extend({ width: '100%' }, opts || {}));
  }

  /* ------------------------------------------------------------------ *
   * Tabs
   * ------------------------------------------------------------------ */
  $('.tabs .tab').on('click', function () {
    var t = $(this).data('tab');
    $('.tabs .tab').removeClass('active');
    $(this).addClass('active');
    $('.tab-panel').removeClass('active');
    $('#panel-' + t).addClass('active');
  });

  initSelect2($('#pfRegion'), { placeholder: 'Select region' });
  initSelect2($('#sysRegion'), { placeholder: 'Select region' });

  // Regions for both dropdowns (dynamic geography).
  function loadRegions() {
    cmsAjax({
      url: '/api/geography/regions', method: 'GET',
      success: function (res) {
        var regions = res || [];
        ['#pfRegion', '#sysRegion'].forEach(function (sel) {
          var $sel = $(sel);
          var cur = $sel.val();
          $sel.find('option[value!=""]').remove();
          regions.forEach(function (r) {
            var name = r.regionName || r.name;
            if (name) $sel.append($('<option>').text(name));
          });
          if (cur) $sel.val(cur).trigger('change');
        });
      }
    });
  }

  function initials(name) {
    if (!name) return '–';
    var parts = $.trim(name).split(/\s+/);
    return (parts[0].charAt(0) + (parts.length > 1 ? parts[parts.length - 1].charAt(0) : '')).toUpperCase();
  }

  /* ------------------------------------------------------------------ *
   * Profile — GET/PUT /api/settings/profile
   * ------------------------------------------------------------------ */
  function loadProfile() {
    cmsAjax({
      url: '/api/settings/profile', method: 'GET',
      fallbackMsg: 'Could not load profile.',
      success: function (p) {
        p = p || {};
        var name = p.displayName || p.username || '';
        $('#pfName').val(name);
        $('#pfEmail').val(p.email || '');
        $('#pfPhone').val(p.phone || '');
        $('#pfUsername').val(p.username || '');
        if (p.region) $('#pfRegion').val(p.region).trigger('change');
        $('#pfBio').val(p.bio || '');
        $('#pfAvatar').text(initials(name));
        $('#pfDisplayTitle').text(name || '—');
        $('#pfDisplaySub').text(p.username ? '@' + p.username : '');
      }
    });
  }

  $('#profileForm').on('submit', function (e) {
    e.preventDefault();
    var $f = $(this);
    $f.find('.field').removeClass('invalid');
    var ok = true;
    $f.find('[required]').each(function () {
      if (!$.trim($(this).val() || '')) {
        $(this).closest('.field').addClass('invalid');
        $(this).closest('.field').find('.field-error').text('This field is required.');
        ok = false;
      }
    });
    if (!ok) return;
    CMS.loader(true);
    cmsAjax({
      url: '/api/settings/profile', method: 'PUT', json: true,
      data: {
        displayName: $.trim($('#pfName').val()),
        email: $.trim($('#pfEmail').val()),
        phone: $.trim($('#pfPhone').val()) || null,
        region: $('#pfRegion').val() || null,
        bio: $.trim($('#pfBio').val()) || null
      },
      fallbackMsg: 'Could not save profile.',
      success: function (p) {
        CMS.loader(false);
        CMS.toast('Profile updated', 'success');
        var name = (p && p.displayName) || $.trim($('#pfName').val());
        $('#pfAvatar').text(initials(name));
        $('#pfDisplayTitle').text(name || '—');
      },
      error: function () { CMS.loader(false); }
    });
  });

  /* ------------------------------------------------------------------ *
   * Notifications — GET/PUT /api/settings/notifications
   * ------------------------------------------------------------------ */
  var notifMap = { ntEmail: 'emailAlerts', ntSms: 'smsReminders', ntDigest: 'followUpDigests', ntCrisis: 'crisisAlerts' };

  function loadNotifications() {
    cmsAjax({
      url: '/api/settings/notifications', method: 'GET',
      fallbackMsg: 'Could not load notification preferences.',
      success: function (n) {
        n = n || {};
        Object.keys(notifMap).forEach(function (id) {
          $('#' + id).prop('checked', !!n[notifMap[id]]);
        });
      }
    });
  }

  $('#panel-notif .switch input').on('change', function () {
    var id = this.id;
    var on = $(this).is(':checked');
    var label = $(this).closest('.check-row').find('b').text();
    cmsAjax({
      url: '/api/settings/notifications', method: 'PUT', json: true,
      data: {
        emailAlerts: $('#ntEmail').is(':checked'),
        smsReminders: $('#ntSms').is(':checked'),
        followUpDigests: $('#ntDigest').is(':checked'),
        crisisAlerts: $('#ntCrisis').is(':checked')
      },
      fallbackMsg: 'Could not save notification preferences.',
      success: function () { CMS.toast(label + ': ' + (on ? 'On' : 'Off'), 'info'); },
      error: function () { $('#' + id).prop('checked', !on); }
    });
  });

  /* ------------------------------------------------------------------ *
   * System — GET/PUT /api/settings/system
   * ------------------------------------------------------------------ */
  function loadSystem() {
    cmsAjax({
      url: '/api/settings/system', method: 'GET',
      fallbackMsg: 'Could not load system settings.',
      success: function (s) {
        s = s || {};
        if (s.defaultRegion) $('#sysRegion').val(s.defaultRegion).trigger('change');
        $('#sysTimeout').val(String(s.sessionTimeout || 30));
        $('#sysRetention').val(s.dataRetentionMonths || 24);
      }
    });
  }

  $('#systemForm').on('submit', function (e) {
    e.preventDefault();
    CMS.loader(true);
    cmsAjax({
      url: '/api/settings/system', method: 'PUT', json: true,
      data: {
        defaultRegion: $('#sysRegion').val() || null,
        sessionTimeout: parseInt($('#sysTimeout').val(), 10) || 30,
        dataRetentionMonths: parseInt($('#sysRetention').val(), 10) || 24
      },
      fallbackMsg: 'Could not save system settings.',
      success: function () { CMS.loader(false); CMS.toast('System settings saved', 'success'); },
      error: function () { CMS.loader(false); }
    });
  });

  /* ------------------------------------------------------------------ *
   * Danger zone — clear local data
   * ------------------------------------------------------------------ */
  $('#clearData').on('click', function () {
    if (confirm('Clear all locally stored CMS data (safety plans, treatment plans, preferences)? This cannot be undone.')) {
      ['cms_safety_plan', 'cms_treatment_plan', 'cms_settings'].forEach(function (k) {
        try { localStorage.removeItem(k); } catch (e) { /* ignore */ }
      });
      CMS.toast('Local data cleared', 'success');
    }
  });

  loadRegions();
  loadProfile();
  loadNotifications();
  loadSystem();
});
