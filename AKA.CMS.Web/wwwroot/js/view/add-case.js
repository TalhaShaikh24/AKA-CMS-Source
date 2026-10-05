/* Add Case — demo-only port of the template view script — no API calls. Wizard validation + review run locally; final submit is a demo toast only. */
$(function () {
  CMS.initSelect2($('#wizardForm'));

  var step = 1, totalSteps = 3;
  var $steps = $('.wizard-step');
  var $stepperSteps = $('#wizardStepper .step');

  // ---- Age options ----
  var ageOpts = '<option value="">Select&hellip;</option>';
  for (var a = 10; a <= 90; a++) ageOpts += '<option>' + a + '</option>';
  $('#fAge').html(ageOpts).trigger('change');

  // ---- Screening tools with score inputs ----
  var tools = [
    { tool: 'PHQ-9', max: 27 },
    { tool: 'GAD-7', max: 21 },
    { tool: 'DASS-21', max: 63 },
    { tool: 'SBQ-R', max: 23 },
    { tool: 'C-SSRS', max: 6 }
  ];
  var $toolsWrap = $('#screeningTools').empty();
  $.each(tools, function (i, t) {
    var $row = $(
      '<div class="check-row screen-tool">' +
        '<input type="checkbox" id="tool_' + i + '" data-tool="' + t.tool + '">' +
        '<span class="check-label"><strong>' + t.tool + '</strong></span>' +
        '<input class="input score-input" type="number" min="0" max="' + t.max + '" placeholder="Score (0–' + t.max + ')" disabled hidden>' +
      '</div>'
    );
    $toolsWrap.append($row);
  });
  $toolsWrap.on('change', 'input[type=checkbox]', function () {
    var $row = $(this).closest('.screen-tool');
    var on = $(this).is(':checked');
    $row.find('.score-input').prop({ disabled: !on, hidden: !on }).val('');
  });

  // ---- Risk pills selection state ----
  $('#riskPills').on('change', 'input[name=risk]', function () {
    $('#riskPills .risk-pill').removeClass('selected');
    $(this).closest('.risk-pill').addClass('selected');
    $('#riskError').text('');
  });

  // ---- Step navigation ----
  function showStep(n) {
    step = Math.max(1, Math.min(totalSteps, n));
    $steps.removeClass('active');
    $('#s' + step).addClass('active');
    $stepperSteps.each(function () {
      var s = +$(this).data('step');
      $(this).toggleClass('active', s === step).toggleClass('done', s < step);
    });
    $('#wizBack').toggle(step > 1);
    $('#wizNext').prop('hidden', step === totalSteps);
    $('#wizSubmit').prop('hidden', step !== totalSteps);
    if (step === 3) renderReview();
  }

  // ---- Per-step validation (visible step only) ----
  function setError($el, msg) {
    var $field = $el.closest('.field');
    var $err = $field.find('.field-error');
    if ($err.length) $err.text(msg);
    $el.addClass('invalid');
  }
  function clearError($el) {
    $el.removeClass('invalid');
    var $err = $el.closest('.field').find('.field-error');
    if ($err.length) $err.text('');
  }
  function validPhone(v) {
    return !v || /^[+\d][\d\s\-()]{6,}$/.test(v.trim());
  }
  function validateStep(n) {
    var ok = true;
    $('#s' + n).find('[required]').each(function () {
      var $el = $(this);
      clearError($el);
      var type = $el.attr('type');
      if (type === 'checkbox') {
        if (!$el.is(':checked')) { setError($el, 'This field is required.'); ok = false; }
      } else if (type === 'radio') {
        // handled once per group below
      } else {
        var v = $.trim($el.val() || '');
        if (!v) { setError($el, 'This field is required.'); ok = false; }
        else if ($el.attr('data-minlength') && v.length < +$el.attr('data-minlength')) {
          setError($el, 'Must be at least ' + $el.attr('data-minlength') + ' characters.'); ok = false;
        }
        else if ($el.data('validate') === 'phone' || $el.attr('data-validate') === 'phone') {
          if (!validPhone(v)) { setError($el, 'Enter a valid phone number.'); ok = false; }
        }
      }
    });
    // radio groups (risk pills) — one check per group
    $('#s' + n).find('input[type=radio][required]').each(function () {
      var name = $(this).attr('name');
      if (!$('input[name="' + name + '"]:checked').length) {
        $('#riskError').text('Please select a risk level.');
        ok = false;
        return false;
      }
    });
    return ok;
  }

  $('#wizardForm').on('input change', '[required]', function () { clearError($(this)); });
  $('#wizBack').on('click', function () { showStep(step - 1); });
  $('#wizNext').on('click', function () {
    if (validateStep(step)) showStep(step + 1);
  });

  // ---- Review ----
  function row(k, v) {
    return '<div class="kv"><span class="k">' + $('<div>').text(k).html() + '</span><span class="v">' +
      $('<div>').text(v || '—').html() + '</span></div>';
  }
  function renderReview() {
    var done = [];
    $('#screeningTools input[type=checkbox]:checked').each(function () {
      var $row = $(this).closest('.screen-tool');
      var score = $row.find('.score-input').val();
      done.push($(this).data('tool') + (score ? ' (score ' + score + ')' : ''));
    });
    var risk = $('input[name=risk]:checked').val();
    var html = '<h4>Personal information</h4><div class="kv-grid">' +
      row('Full name', $('#fName').val()) + row('Age', $('#fAge').val()) +
      row('Phone', $('#fPhone').val()) + row('Gender', $('#fGender').val()) +
      row('Region council', $('#fRegion').val()) + row('Local council', $('#fLocal').val()) +
      row('Village', $('#fVillage').val()) + row('Language', $('#fLang').val()) +
      row('Employment', $('#fEmp').val()) + row('Marital status', $('#fMarital').val()) +
      row('Children', $('#fChildren').val()) + row('Health insurance', $('#fInsurance').val()) +
      row('GP', $('#fGp').val()) + row('Prior MH treatment', $('#fPrior').val()) +
      row('Connected to MH care', $('#fConnected').val()) + '</div>' +
      '<h4>Screening</h4><div class="kv-grid">' +
      row('Tools completed', done.length ? done.join(', ') : 'None') +
      row('Risk level', risk ? CMS.riskBadge(risk) : '—') + '</div>';
    $('#reviewBox').html(html);
  }

  // ---- Submit ----
  $('#wizSubmit').on('click', function () {
    if (!validateStep(3)) return;
    CMS.loader(false);
    CMS.toast('Demo mode — case registration is not connected to the API yet.', 'info');
  });

  showStep(1);
});
