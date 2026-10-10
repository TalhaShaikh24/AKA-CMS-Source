/* ==========================================================================
   CMS · Register New Case — js/view/add-case.js
   Matches the CMO design: 4 steps (Personal Info → Risk Assessment →
   Screening → Review). Region/Local Council/Village dropdowns are loaded
   dynamically from /api/geography. Submit flow (unchanged backend):
     1. POST /api/patients/members  → register the community member
     2. POST /api/cases              → create the case for that member
     3. redirect → /Screening?caseId={id}
   ========================================================================== */
$(function () {
  'use strict';
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2($('#regForm'));
  CMS.initValidation(document);

  var step = 1;
  var geo = { regions: [], councils: [], villages: [] };

  // Age dropdown (old theme style: individual ages 1-100).
  (function buildAgeOptions() {
    var html = '<option value="" selected disabled>Select age</option>';
    for (var a = 1; a <= 100; a++) html += '<option value="' + a + '">' + a + '</option>';
    $('#fAge').html(html).trigger('change');
  })();

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function val(id) { return $.trim($('#' + id).val() || ''); }
  function text(id) {
    var $el = $('#' + id), v = $el.val();
    if ($el.is('select')) { var t = $.trim($el.find('option:selected').text()); return v ? t : ''; }
    return $.trim(v || '');
  }

  /* ---------- geography dropdowns (dynamic) ---------- */
  function fillSelect($sel, items, textKey, placeholder) {
    var html = '<option value="" selected disabled>' + placeholder + '</option>';
    items.forEach(function (it) {
      html += '<option value="' + esc(it[textKey]) + '">' + esc(it[textKey]) + '</option>';
    });
    $sel.html(html).trigger('change');
  }
  function loadGeography() {
    cmsAjax({ url: '/api/geography/regions', method: 'GET',
      fallbackMsg: 'Could not load regions.',
      success: function (res) {
        geo.regions = res || [];
        fillSelect($('#fRegion'), geo.regions, 'regionName', 'Select region');
      }
    });
    cmsAjax({ url: '/api/geography/councils', method: 'GET',
      fallbackMsg: 'Could not load local councils.',
      success: function (res) {
        geo.councils = res || [];
        applyCouncilFilter();
      }
    });
    cmsAjax({ url: '/api/geography/villages', method: 'GET',
      fallbackMsg: 'Could not load villages.',
      success: function (res) {
        geo.villages = res || [];
        applyVillageFilter();
      }
    });
  }
  function applyCouncilFilter() {
    var regionName = val('fRegion');
    var region = geo.regions.filter(function (r) { return r.regionName === regionName; })[0];
    var list = region
      ? geo.councils.filter(function (c) { return !c.regionId || c.regionId === region.regionId; })
      : geo.councils;
    var cur = val('fLocalCouncil');
    fillSelect($('#fLocalCouncil'), list, 'councilName', 'Select local council');
    if (cur) $('#fLocalCouncil').val(cur);
    applyVillageFilter();
  }
  function applyVillageFilter() {
    var councilName = val('fLocalCouncil');
    var council = geo.councils.filter(function (c) { return c.councilName === councilName; })[0];
    var list = council
      ? geo.villages.filter(function (v) { return !v.councilId || v.councilId === council.councilId; })
      : geo.villages;
    var cur = val('fVillage');
    fillSelect($('#fVillage'), list, 'villageName', 'Select village');
    if (cur) $('#fVillage').val(cur);
  }
  $('#fRegion').on('change', applyCouncilFilter);
  $('#fLocalCouncil').on('change', applyVillageFilter);

  /* ---------- screening tools (design info cards) ---------- */
  var tools = ['PHQ-9 (Depression)', 'GAD-7 (Anxiety)', 'DASS-21 (Stress/Depression/Anxiety)', 'SBQ-R (Suicide Risk)', 'C-SSRS (Suicidal Ideation/Behavior)'];
  $('#screenTools').html(tools.map(function (t) {
    return '<div class="quick card" style="box-shadow:none"><div class="left"><div class="qicon">✓</div><div><b>' + esc(t) + '</b>' +
      '<div style="font-size:12px;color:#8995a7">Available after registration</div></div></div></div>';
  }).join(''));

  /* ---------- steps ---------- */
  function showStep(n) {
    step = n;
    $('.reg-step').prop('hidden', true);
    $('#rs' + n).prop('hidden', false);
    $('#regSteps .step').each(function () {
      var s = parseInt($(this).data('step'), 10);
      $(this).toggleClass('done', s < n).toggleClass('current', s === n);
      $(this).find('.circle').text(s < n ? '✓' : s);
    });
    if (n === 4) buildReview();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function validateStep(n) {
    var ok = true;
    var $scope = $('#rs' + n);
    $scope.find('.field').removeClass('invalid');
    $scope.find('[required]').each(function () {
      var $f = $(this);
      if (!$.trim($f.val() || '')) {
        $f.closest('.field').addClass('invalid');
        $f.closest('.field').find('.field-error').text('This field is required.');
        ok = false;
      }
    });
    if (n === 1) {
      var phone = val('fPhone');
      if (phone && window.CMS && typeof CMS.validatePhone === 'function' && !CMS.validatePhone(phone)) {
        $('#fPhone').closest('.field').addClass('invalid');
        $('#fPhone').closest('.field').find('.field-error').text('Enter a valid phone number.');
        ok = false;
      }
    }
    if (!ok) CMS.toast('Please fix the highlighted fields.', 'error');
    return ok;
  }

  $('#rsNext1').on('click', function () { if (validateStep(1)) showStep(2); });
  $('#rsNext2').on('click', function () { showStep(3); });
  $('#rsNext3').on('click', function () { showStep(4); });
  $('#rsBack2').on('click', function () { showStep(1); });
  $('#rsBack3').on('click', function () { showStep(2); });
  $('#rsBack4').on('click', function () { showStep(3); });
  $('[data-go]').on('click', function () { location.href = $(this).data('go'); });

  /* ---------- review ---------- */
  function kvRow(k, v) {
    if (!v) return '';
    return '<div class="k">' + esc(k) + '</div><div class="v">' + esc(v) + '</div>';
  }
  function buildReview() {
    $('#revPersonal').html(
      kvRow('Name', val('fName')) +
      kvRow('Age', val('fAge')) +
      kvRow('Gender', text('fGender')) +
      kvRow('Phone', val('fPhone')) +
      kvRow('Location', [text('fVillage'), text('fLocalCouncil'), text('fRegion')].filter(Boolean).join(', '))
    );
    $('#revConcern').text(val('fConcern') || '—');
    var riskBits = [];
    if (text('fRiskCat')) riskBits.push(text('fRiskCat') + ' risk');
    if (text('fIsCrisis') === 'Yes') riskBits.push('active crisis');
    $('#revRisk').text(riskBits.join(' / ') || '—');
  }

  /* ---------- submit: member → case → screening ---------- */
  $('#rsSubmit').on('click', function () {
    if (!validateStep(1)) { showStep(1); return; }

    var ageVal = val('fAge');
    var memberPayload = {
      fullName: val('fName'),
      gender: text('fGender') || null,
      phone: val('fPhone') || null,
      age: ageVal ? parseInt(ageVal, 10) : null,
      regionCouncil: text('fRegion') || null,
      localCouncil: text('fLocalCouncil') || null,
      village: text('fVillage') || null,
      jkAttend: text('fJk') || null,
      employmentEducation: text('fEmployment') || null,
      maritalStatus: text('fMarital') || null,
      languagesSpoken: val('fLanguages') || null,
      healthInsurance: text('fInsurance') || null,
      gpUsualCare: text('fGp') || null,
      priorMhTreatment: text('fPriorMh') || null,
      connectedToMhCare: text('fConnectedMh') || null
    };
    var riskCat = text('fRiskCat');
    var priorityMap = { 'Low': 'Low', 'Moderate': 'Moderate', 'High': 'High', 'Critical': 'High' };
    var notesBits = [];
    if (val('fConcern')) notesBits.push(val('fConcern'));
    if (text('fIsCrisis')) notesBits.push('Crisis: ' + text('fIsCrisis'));
    if (riskCat) notesBits.push('Risk: ' + riskCat);
    if (val('fAssessor')) notesBits.push('Assessor: ' + val('fAssessor'));
    var casePayload = {
      sourceType: 'WalkIn',
      priorityLevel: priorityMap[riskCat] || null,
      notes: notesBits.join(' | ') || null
    };

    CMS.loader(true);
    cmsAjax({
      url: '/api/patients/members',
      method: 'POST',
      json: true,
      data: memberPayload,
      fallbackMsg: 'Could not register the patient.',
      success: function (member) {
        casePayload.communityMemberId = member.memberId;
        cmsAjax({
          url: '/api/cases',
          method: 'POST',
          json: true,
          data: casePayload,
          fallbackMsg: 'Patient registered, but the case could not be created.',
          success: function (c) {
            CMS.loader(false);
            CMS.toast('Case ' + (c.caseNumber || ('#' + c.caseId)) + ' registered.', 'success');
            location.href = '/Screening?caseId=' + c.caseId;
          },
          error: function () { CMS.loader(false); }
        });
      },
      error: function () { CMS.loader(false); }
    });
  });

  loadGeography();
  showStep(1);
});
