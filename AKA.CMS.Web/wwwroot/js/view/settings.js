/* Settings — demo-only port of the template view script — no API calls. Persists to localStorage only. */
$(function () {

  var KEY = 'cms_settings';

  function initSelect2($el, opts) {
    if (!$el.length || !$.fn.select2 || $el.data('select2')) return;
    $el.select2($.extend({ width: '100%' }, opts || {}));
  }
  function loadSettings() {
    try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch (e) { return {}; }
  }
  function saveSettings(patch) {
    var s = $.extend(loadSettings(), patch || {});
    try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { /* storage unavailable */ }
    return s;
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

  /* ------------------------------------------------------------------ *
   * Profile form
   * ------------------------------------------------------------------ */
  $('#profileForm').on('submit', function (e) {
    e.preventDefault();
    saveSettings({
      profile: {
        name: $('#pfName').val(),
        email: $('#pfEmail').val(),
        phone: $('#pfPhone').val(),
        region: $('#pfRegion').val(),
        bio: $('#pfBio').val()
      }
    });
    CMS.toast('Profile updated', 'success');
  });

  /* ------------------------------------------------------------------ *
   * Notification toggles
   * ------------------------------------------------------------------ */
  var saved = loadSettings().notifications || {};
  $('#panel-notif .switch input').each(function () {
    var id = this.id;
    if (saved[id] !== undefined) this.checked = !!saved[id];
  });
  $('#panel-notif .switch input').on('change', function () {
    var label = $(this).closest('.check-row').find('b').text();
    var patch = { notifications: {} };
    patch.notifications[this.id] = $(this).is(':checked');
    saveSettings(patch);
    CMS.toast(label + ': ' + ($(this).is(':checked') ? 'On' : 'Off'), 'info');
  });

  /* ------------------------------------------------------------------ *
   * System form
   * ------------------------------------------------------------------ */
  $('#systemForm').on('submit', function (e) {
    e.preventDefault();
    saveSettings({
      system: {
        region: $('#sysRegion').val(),
        timeout: $('#sysTimeout').val(),
        retention: $('#sysRetention').val()
      }
    });
    CMS.toast('System settings saved', 'success');
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
});
