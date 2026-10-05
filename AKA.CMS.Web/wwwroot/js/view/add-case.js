/* ==========================================================================
   CMS · Register New Case — js/view/add-case.js
   API-wired (no demo data) — matches the real backend flow:
     1. POST /api/patients/members  → register the community member
     2. POST /api/cases              → create the case for that member
     3. redirect → /Screening?caseId={id} for the actual screening
   Screening is NOT collected here: the API scores screenings
   server-side after the case exists.
   ========================================================================== */
$(function () {
  'use strict';

  CMS.initSelect2($('#wizardForm'));

  var step = 1;

  function showStep(n) {
    step = n;
    $('.wizard-step').removeClass('active');
    $('#s' + n).addClass('active');
    $('#wizardStepper .step').each(function () {
      $(this).toggleClass('active', parseInt($(this).data('step'), 10) <= n);
    });
    $('#wizBack').prop('hidden', n === 1);
    $('#wizNext').prop('hidden', n === 3);
    $('#wizSubmit').prop('hidden', n !== 3);
    if (n === 3) buildReview();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function fieldVal(id) { return $.trim($('#' + id).val() || ''); }
  function fieldText(id) {
    var $el = $('#' + id);
    var v = $el.val();
    if ($el.is('select')) {
      var t = $el.find('option:selected').text();
      return $.trim(t) && v ? $.trim(t) : '';
    }
    return $.trim(v || '');
  }
  function markInvalid($f, msg) {
    $f.addClass('invalid');
    $f.closest('.field').find('.field-error').text(msg || 'This field is required.');
  }
  function clearInvalid(scope) {
    $(scope).find('.invalid').removeClass('invalid');
    $(scope).find('.field-error').text('');
  }

  function validateStep(n) {
    var ok = true;
    clearInvalid('#s' + n);
    $('#s' + n).find('[required]').each(function () {
      var $f = $(this);
      var valid = true;
      if ($f.is(':checkbox')) valid = $f.is(':checked');
      else valid = $.trim($f.val() || '') !== '';
      if (!valid) { markInvalid($f); ok = false; }
    });
    // Phone format check (shared validator attribute).
    var phone = fieldVal('fPhone');
    if (phone && window.CMS && typeof CMS.validatePhone === 'function' && !CMS.validatePhone(phone)) {
      markInvalid($('#fPhone'), 'Enter a valid phone number.');
      ok = false;
    }
    return ok;
  }

  $('#wizNext').on('click', function () {
    if (validateStep(step)) showStep(Math.min(3, step + 1));
  });
  $('#wizBack').on('click', function () {
    showStep(Math.max(1, step - 1));
  });
  $('#wizardStepper').on('click', '.step', function () {
    var n = parseInt($(this).data('step'), 10);
    if (n < step) showStep(n);
  });

  function reviewRow(k, v) {
    if (!v) return '';
    var d = document.createElement('div');
    d.textContent = v;
    return '<div class="rev-row"><span>' + k + '</span><strong>' + d.innerHTML + '</strong></div>';
  }

  function buildReview() {
    var html = '<h4 class="sec-sub">Patient</h4>' +
      reviewRow('Full name', fieldVal('fName')) +
      reviewRow('Father name', fieldVal('fFather')) +
      reviewRow('Gender', fieldText('fGender')) +
      reviewRow('Date of birth', fieldVal('fDob')) +
      reviewRow('CNIC', fieldVal('fCnic')) +
      reviewRow('Phone', fieldVal('fPhone')) +
      reviewRow('Address', fieldVal('fAddress')) +
      '<h4 class="sec-sub">Case</h4>' +
      reviewRow('Source', fieldText('fSource')) +
      reviewRow('Priority', fieldText('fPriority')) +
      reviewRow('Notes', fieldVal('fNotes'));
    $('#reviewBox').html(html);
  }

  /* ------------------------------------------------------------------ *
   * Submit: member → case → screening page
   * ------------------------------------------------------------------ */
  $('#wizSubmit').on('click', function () {
    if (!validateStep(1) || !validateStep(2)) { showStep(1); return; }
    if (!$('#fConsent').is(':checked')) {
      markInvalid($('#fConsent'), 'Consent is required.');
      CMS.toast('Patient consent is required.', 'error');
      return;
    }

    var dob = fieldVal('fDob');
    var memberPayload = {
      fullName: fieldVal('fName'),
      fatherName: fieldVal('fFather') || null,
      gender: fieldVal('fGender') || null,
      dateOfBirth: dob || null,
      cnic: fieldVal('fCnic') || null,
      phone: fieldVal('fPhone') || null,
      address: fieldVal('fAddress') || null
    };
    var casePayload = {
      sourceType: fieldVal('fSource'),
      priorityLevel: fieldVal('fPriority') || null,
      notes: fieldVal('fNotes') || null
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

  showStep(1);
});
