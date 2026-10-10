/* Facilities — facility directory, loaded through the global cmsAjax helper,
   DIRECTLY from the Web API. Razor never touches the backend. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);
  CMS.initValidation(document);

  var allFacilities = [];
  var editingId = null;
  var editingRowVersion = null;

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

  /* ---------- load ---------- */
  function load() {
    cmsAjax({
      url: '/api/facilities?includeInactive=true', method: 'GET',
      fallbackMsg: 'Could not load facilities.',
      success: function (res) { allFacilities = res || []; render(); }
    });
  }

  function render() {
    var html = '';
    allFacilities.forEach(function (f) {
      var sub = [f.facilityType, f.region].filter(Boolean).join(' · ') || '—';
      if (f.phone) sub += ' · ' + esc(f.phone);
      html += '<div class="geo-card">' +
        '<div class="geo-card-main"><div class="geo-card-name">' + esc(f.facilityName) + '</div>' +
        '<div class="geo-card-sub">' + esc(f.facilityCode) + ' · ' + sub + '</div></div>' +
        '<div class="geo-card-side">' +
        '<span class="badge ' + (f.isActive ? 'st-active' : 'st-ltfu') + '">' + (f.isActive ? 'Active' : 'Inactive') + '</span>' +
        '<button class="btn btn-ghost btn-sm geo-edit" data-edit="' + f.facilityId + '" data-permission="Facilities:Write" type="button">Edit</button>' +
        '</div></div>';
    });
    $('#facilityRows').html(html || '<div class="hint geo-empty">No facilities found.</div>');
    if (window.CMS && typeof CMS.applyPermissions === 'function') CMS.applyPermissions(document);
  }

  /* ---------- modal ---------- */
  function openModal(f) {
    editingId = f ? f.facilityId : null;
    editingRowVersion = f ? f.rowVersion : null;
    $('#facilityModalTitle').text(f ? 'Edit Facility' : 'Add Facility');
    $('#fCode').val(f ? f.facilityCode : '').prop('disabled', !!f);
    $('#fName').val(f ? f.facilityName : '');
    $('#fType').val(f ? (f.facilityType || '') : '').trigger('change');
    $('#fRegion').val(f ? (f.region || '') : '');
    $('#fAddress').val(f ? (f.address || '') : '');
    $('#fPhone').val(f ? (f.phone || '') : '');
    $('#fActive').val(f ? String(!!f.isActive) : 'true').trigger('change');
    $('#facilityForm').find('.field').removeClass('invalid');
    $('#facilityForm').find('.field-error').text('');
    $('#facilityModal').addClass('open').css('display', 'flex');
  }
  function closeModal() { $('#facilityModal').removeClass('open').css('display', 'none'); }

  $('#addFacilityBtn').on('click', function () { openModal(null); });
  $('#facilityCancelBtn').on('click', closeModal);
  $('#facilityModal').on('click', function (e) { if (e.target === this) closeModal(); });
  $('#facilityRows').on('click', '[data-edit]', function () {
    var id = +$(this).data('edit');
    var f = allFacilities.find(function (x) { return x.facilityId === id; });
    if (f) openModal(f);
  });

  /* ---------- save ---------- */
  $('#facilityForm').on('submit', function (e) {
    e.preventDefault();
    var ok = true;
    $('#facilityForm').find('.field').removeClass('invalid');
    $('#facilityForm [required]').each(function () {
      if (!$.trim($(this).val() || '')) {
        ok = false;
        $(this).closest('.field').addClass('invalid')
          .find('.field-error').text('This field is required');
      }
    });
    if (!ok) return;

    var payload = {
      facilityName: $.trim($('#fName').val()),
      facilityType: $('#fType').val() || null,
      region: $.trim($('#fRegion').val()) || null,
      address: $.trim($('#fAddress').val()) || null,
      phone: $.trim($('#fPhone').val()) || null,
      isActive: $('#fActive').val() === 'true',
      rowVersion: editingRowVersion
    };

    if (editingId) {
      cmsAjax({
        url: '/api/facilities/' + editingId, method: 'PUT',
        data: payload, json: true, fallbackMsg: 'Could not update the facility.',
        success: function () { closeModal(); CMS.toast('Facility updated.', 'success'); load(); }
      });
    } else {
      payload.facilityCode = $.trim($('#fCode').val());
      cmsAjax({
        url: '/api/facilities', method: 'POST',
        data: payload, json: true, fallbackMsg: 'Could not create the facility.',
        success: function () { closeModal(); CMS.toast('Facility added.', 'success'); load(); }
      });
    }
  });

  load();
});
