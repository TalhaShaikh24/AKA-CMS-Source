/* Treatment Plan — demo-only port of the template view script — no API calls. Persists to localStorage only. */
$(function () {

  var KEY = 'cms_treatment_plan';
  var DIAGNOSES = [
    'Major Depressive Disorder', 'Generalized Anxiety Disorder', 'Post-Traumatic Stress Disorder',
    'Bipolar Disorder', 'Obsessive-Compulsive Disorder', 'Adjustment Disorder',
    'Substance Use Disorder', 'Schizophrenia'
  ];
  var STATUS_CLASS = { 'Active': 'low', 'Planned': 'moderate', 'On hold': 'high', 'Completed': 'low' };

  var state = {
    goals: [{ text: 'Reduce panic episodes to fewer than one per week', target: '2026-10-31' }],
    interventions: [{ name: 'Cognitive Behavioral Therapy', freq: 'Weekly', provider: 'Ayesha Khan', status: 'Active' }],
    meds: [{ name: 'Sertraline', dose: '50 mg', freq: 'Once daily' }]
  };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function initSelect2($el, opts) {
    if (!$el.length || !$.fn.select2 || $el.data('select2')) return;
    $el.select2($.extend({ width: '100%' }, opts || {}));
  }
  function normalizeDate(s) {
    s = $.trim(s || '');
    if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
    var d = new Date(s);
    return isNaN(d) ? '' : d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2);
  }

  /* ------------------------------------------------------------------ *
   * Patient + diagnosis selects
   * ------------------------------------------------------------------ */
  var cases = (CMS.demo && CMS.demo.cases) || [];
  var $patient = $('#tpPatient');
  cases.forEach(function (c) {
    $patient.append('<option value="' + esc(c.id) + '">' + esc(c.name) + ' · ' + esc(c.id) + '</option>');
  });
  initSelect2($patient, { placeholder: 'Select patient' });

  var $diag = $('#tpDiagnosis');
  DIAGNOSES.forEach(function (d) { $diag.append('<option>' + d + '</option>'); });
  initSelect2($diag, { placeholder: 'Select diagnosis' });

  /* ------------------------------------------------------------------ *
   * Goals (goal text + target date)
   * ------------------------------------------------------------------ */
  function renderGoals() {
    $('#tpGoalList').html(state.goals.map(function (g, i) {
      return '<div class="chip"><span><b>' + esc(g.text) + '</b>' +
        ' <i class="hint">target ' + esc(g.target || '—') + '</i></span>' +
        '<button type="button" class="chip-x" data-i="' + i + '" aria-label="Remove">&times;</button></div>';
    }).join('') || '<div class="empty">No goals added yet.</div>');
  }
  $('#tpGoalAdd').on('click', function () {
    var text = $.trim($('#tpGoalText').val());
    if (!text) { CMS.toast('Describe the goal first', 'error'); return; }
    state.goals.push({ text: text, target: normalizeDate($('#tpGoalDate').val()) });
    $('#tpGoalText,#tpGoalDate').val('');
    renderGoals();
  });
  $('#tpGoalList').on('click', '.chip-x', function () {
    state.goals.splice(+$(this).data('i'), 1);
    renderGoals();
  });

  /* ------------------------------------------------------------------ *
   * Interventions table + inline add form
   * ------------------------------------------------------------------ */
  function renderInterventions() {
    $('#tpIntTbody').html(state.interventions.map(function (r, i) {
      var cls = STATUS_CLASS[r.status] || 'moderate';
      return '<tr><td><div class="cell-main">' + esc(r.name) + '</div></td>' +
        '<td>' + esc(r.freq) + '</td><td>' + esc(r.provider) + '</td>' +
        '<td><span class="badge badge-' + cls + '">' + esc(r.status) + '</span></td>' +
        '<td class="row-actions"><button type="button" class="btn btn-ghost btn-sm" data-i="' + i + '">Remove</button></td></tr>';
    }).join('') || '<tr><td colspan="5"><div class="empty">No interventions added yet.</div></td></tr>');
  }
  $('#tpIntAdd').on('click', function () {
    var name = $.trim($('#tpIntName').val());
    if (!name) { CMS.toast('Enter an intervention name', 'error'); return; }
    state.interventions.push({
      name: name,
      freq: $('#tpIntFreq').val(),
      provider: $.trim($('#tpIntProv').val()) || '—',
      status: $('#tpIntStatus').val()
    });
    $('#tpIntName,#tpIntProv').val('');
    renderInterventions();
  });
  $('#tpIntTbody').on('click', 'button', function () {
    state.interventions.splice(+$(this).data('i'), 1);
    renderInterventions();
  });

  /* ------------------------------------------------------------------ *
   * Medication rows
   * ------------------------------------------------------------------ */
  function renderMeds() {
    $('#tpMedTbody').html(state.meds.map(function (m, i) {
      return '<tr><td><div class="cell-main">' + esc(m.name) + '</div></td>' +
        '<td>' + esc(m.dose) + '</td><td>' + esc(m.freq) + '</td>' +
        '<td class="row-actions"><button type="button" class="btn btn-ghost btn-sm" data-i="' + i + '">Remove</button></td></tr>';
    }).join('') || '<tr><td colspan="4"><div class="empty">No medication added yet.</div></td></tr>');
  }
  $('#tpMedAdd').on('click', function () {
    var name = $.trim($('#tpMedName').val());
    if (!name) { CMS.toast('Enter a medication name', 'error'); return; }
    state.meds.push({
      name: name,
      dose: $.trim($('#tpMedDose').val()) || '—',
      freq: $.trim($('#tpMedFreq').val()) || '—'
    });
    $('#tpMedName,#tpMedDose,#tpMedFreq').val('');
    renderMeds();
  });
  $('#tpMedTbody').on('click', 'button', function () {
    state.meds.splice(+$(this).data('i'), 1);
    renderMeds();
  });

  /* ------------------------------------------------------------------ *
   * Persist to localStorage (per patient)
   * ------------------------------------------------------------------ */
  function loadAll() {
    try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch (e) { return {}; }
  }
  function currentKey() { return $patient.val() || 'general'; }

  function collect() {
    return {
      diagnosis: $diag.val(),
      goals: state.goals.slice(),
      interventions: state.interventions.slice(),
      meds: state.meds.slice(),
      reviewDate: normalizeDate($('#tpReviewDate').val()),
      notes: $('#tpNotes').val(),
      updated: new Date().toISOString()
    };
  }

  function apply(data) {
    data = data || {};
    if (data.diagnosis) $diag.val(data.diagnosis).trigger('change');
    state.goals = data.goals || state.goals;
    state.interventions = data.interventions || state.interventions;
    state.meds = data.meds || state.meds;
    $('#tpReviewDate').val(data.reviewDate || '');
    $('#tpNotes').val(data.notes || '');
    renderGoals();
    renderInterventions();
    renderMeds();
    $('#tpSavedHint').text(data.updated ? 'Last saved ' + new Date(data.updated).toLocaleString() : '');
  }

  $('#tpSave').on('click', function () {
    var all = loadAll();
    all[currentKey()] = collect();
    try { localStorage.setItem(KEY, JSON.stringify(all)); } catch (e) { /* storage unavailable */ }
    $('#tpSavedHint').text('Saved just now');
    CMS.toast('Treatment plan saved', 'success');
  });

  $patient.on('change', function () {
    /* reset to defaults, then overlay any saved plan for this patient */
    var fresh = { goals: [], interventions: [], meds: [] };
    var saved = loadAll()[currentKey()];
    state.goals = (saved && saved.goals) || fresh.goals;
    state.interventions = (saved && saved.interventions) || fresh.interventions;
    state.meds = (saved && saved.meds) || fresh.meds;
    if (saved) { if (saved.diagnosis) $diag.val(saved.diagnosis).trigger('change'); $('#tpReviewDate').val(saved.reviewDate || ''); $('#tpNotes').val(saved.notes || ''); }
    else { $diag.val('').trigger('change'); $('#tpReviewDate,#tpNotes').val(''); }
    renderGoals(); renderInterventions(); renderMeds();
    $('#tpSavedHint').text(saved && saved.updated ? 'Last saved ' + new Date(saved.updated).toLocaleString() : '');
  });

  /* ------------------------------------------------------------------ *
   * Init
   * ------------------------------------------------------------------ */
  renderGoals();
  renderInterventions();
  renderMeds();
});
