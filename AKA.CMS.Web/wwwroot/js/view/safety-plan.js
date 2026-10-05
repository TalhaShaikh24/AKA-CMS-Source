/* Safety Plan — demo-only port of the template view script — no API calls. Persists to localStorage only. */
$(function () {

  var KEY = 'cms_safety_plan';
  var DEFAULT_PROS = [
    { name: 'Crisis Helpline', phone: '1166', note: '24/7 toll-free' },
    { name: 'Emergency Services', phone: '1122', note: 'Rescue 1122' },
    { name: 'Dr. Sana Iqbal', phone: '+92 355 1234567', note: 'Assigned psychiatrist' }
  ];

  var state = { warnings: [], coping: [], contacts: [], pros: DEFAULT_PROS.slice() };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function initSelect2($el, opts) {
    if (!$el.length || !$.fn.select2 || $el.data('select2')) return;
    $el.select2($.extend({ width: '100%' }, opts || {}));
  }

  /* ------------------------------------------------------------------ *
   * Patient select
   * ------------------------------------------------------------------ */
  var cases = (CMS.demo && CMS.demo.cases) || [];
  var $patient = $('#spPatient');
  cases.forEach(function (c) {
    $patient.append('<option value="' + esc(c.id) + '">' + esc(c.name) + ' · ' + esc(c.id) + '</option>');
  });
  initSelect2($patient, { placeholder: 'Select patient' });

  /* ------------------------------------------------------------------ *
   * Dynamic chip lists (warning signs, coping strategies)
   * ------------------------------------------------------------------ */
  function renderChips($list, arr) {
    $list.html(arr.map(function (t, i) {
      return '<li class="chip"><span>' + esc(t) + '</span>' +
        '<button type="button" class="chip-x" data-i="' + i + '" aria-label="Remove">&times;</button></li>';
    }).join(''));
  }
  function bindAdder(inputSel, btnSel, listSel, arr) {
    var $input = $(inputSel), $list = $(listSel);
    function add() {
      var text = $.trim($input.val());
      if (!text) return;
      arr.push(text);
      $input.val('').focus();
      renderChips($list, arr);
    }
    $(btnSel).on('click', add);
    $input.on('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); add(); } });
    $list.on('click', '.chip-x', function () {
      arr.splice(+$(this).data('i'), 1);
      renderChips($list, arr);
    });
  }
  bindAdder('#spWarnInput', '#spWarnAdd', '#spWarnList', state.warnings);
  bindAdder('#spCopeInput', '#spCopeAdd', '#spCopeList', state.coping);

  /* ------------------------------------------------------------------ *
   * Supportive contacts
   * ------------------------------------------------------------------ */
  function renderContacts() {
    $('#spCTbody').html(state.contacts.map(function (c, i) {
      return '<tr><td><div class="cell-main">' + esc(c.name) + '</div></td>' +
        '<td>' + esc(c.phone) + '</td><td>' + esc(c.rel || '—') + '</td>' +
        '<td class="row-actions"><button type="button" class="btn btn-ghost btn-sm" data-i="' + i + '">Remove</button></td></tr>';
    }).join('') || '<tr><td colspan="4"><div class="empty">No contacts added yet.</div></td></tr>');
  }
  $('#spCAdd').on('click', function () {
    var name = $.trim($('#spCName').val());
    var phone = $.trim($('#spCPhone').val());
    var rel = $.trim($('#spCRel').val());
    if (!name || !phone) { CMS.toast('Add at least a name and phone number', 'error'); return; }
    state.contacts.push({ name: name, phone: phone, rel: rel });
    $('#spCName,#spCPhone,#spCRel').val('');
    renderContacts();
  });
  $('#spCTbody').on('click', 'button', function () {
    state.contacts.splice(+$(this).data('i'), 1);
    renderContacts();
  });

  /* ------------------------------------------------------------------ *
   * Professional contacts
   * ------------------------------------------------------------------ */
  function renderPros() {
    $('#spProfList').html(state.pros.map(function (p, i) {
      return '<li class="prow"><div><div class="cell-main">' + esc(p.name) + '</div>' +
        '<div class="hint">' + esc(p.phone) + (p.note ? ' · ' + esc(p.note) : '') + '</div></div>' +
        '<button type="button" class="chip-x" data-i="' + i + '" aria-label="Remove">&times;</button></li>';
    }).join(''));
  }
  $('#spProfAdd').on('click', function () {
    var name = $.trim($('#spProfName').val());
    var phone = $.trim($('#spProfPhone').val());
    if (!name || !phone) { CMS.toast('Add a name and phone number', 'error'); return; }
    state.pros.push({ name: name, phone: phone, note: '' });
    $('#spProfName,#spProfPhone').val('');
    renderPros();
  });
  $('#spProfList').on('click', '.chip-x', function () {
    state.pros.splice(+$(this).data('i'), 1);
    renderPros();
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
      warningText: $('#spWarnText').val(),
      warnings: state.warnings.slice(),
      coping: state.coping.slice(),
      contacts: state.contacts.slice(),
      pros: state.pros.slice(),
      environment: $('.env-check input:checked').map(function () { return this.value; }).get(),
      reasons: $('#spReasons').val(),
      updated: new Date().toISOString()
    };
  }

  function apply(data) {
    data = data || {};
    state.warnings = data.warnings || [];
    state.coping = data.coping || [];
    state.contacts = data.contacts || [];
    state.pros = (data.pros && data.pros.length) ? data.pros : DEFAULT_PROS.slice();
    $('#spWarnText').val(data.warningText || '');
    $('#spReasons').val(data.reasons || '');
    $('.env-check input').each(function () {
      this.checked = (data.environment || []).indexOf(this.value) !== -1;
    });
    renderChips($('#spWarnList'), state.warnings);
    renderChips($('#spCopeList'), state.coping);
    renderContacts();
    renderPros();
    $('#spSavedHint').text(data.updated ? 'Last saved ' + new Date(data.updated).toLocaleString() : '');
  }

  $('#spSave').on('click', function () {
    var all = loadAll();
    all[currentKey()] = collect();
    try { localStorage.setItem(KEY, JSON.stringify(all)); } catch (e) { /* storage unavailable */ }
    $('#spSavedHint').text('Saved just now');
    CMS.toast('Safety plan saved', 'success');
  });

  $patient.on('change', function () { apply(loadAll()[currentKey()]); });

  /* ------------------------------------------------------------------ *
   * Init
   * ------------------------------------------------------------------ */
  apply(loadAll()[currentKey()]);
});
