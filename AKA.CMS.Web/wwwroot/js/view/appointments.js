/* Appointments — demo-only port of the template view script — no API calls. Week strip, filters and booking run against demo data. */
$(function () {

  /* ------------------------------------------------------------------ *
   * Demo data — uses the CMS contract, falls back to built-ins
   * ------------------------------------------------------------------ */
  var FALLBACK_APPTS = [
    { patient: 'Sana Khan',   caseId: 'CM-2025-000123', date: '2026-09-25', time: '10:00 AM', type: 'Psychological Session', mode: 'Teleconsultation', location: 'Counseling Room 1' },
    { patient: 'Imran Khan',  caseId: 'CM-2025-000567', date: '2026-09-25', time: '11:30 AM', type: 'Crisis Review',         mode: 'In-person',        location: 'Counseling Room 2' },
    { patient: 'Fatima Noor', caseId: 'CM-2025-000342', date: '2026-09-26', time: '02:00 PM', type: 'Intake Assessment',     mode: 'Teleconsultation', location: 'Video Link' },
    { patient: 'Usman Tariq', caseId: 'CM-2025-000098', date: '2026-09-27', time: '10:30 AM', type: 'Safety Plan Review',    mode: 'In-person',        location: 'Counseling Room 2' },
    { patient: 'Laiba Khan',  caseId: 'CM-2025-000124', date: '2026-09-28', time: '12:00 PM', type: 'Family Session',        mode: 'In-person',        location: 'Counseling Room 1' },
    { patient: 'Ali Raza',    caseId: 'CM-2025-000231', date: '2026-09-29', time: '09:30 AM', type: 'Follow-up',             mode: 'Teleconsultation', location: 'Video Link' }
  ];

  var seed = (CMS.demo && CMS.demo.appointments && CMS.demo.appointments.length)
    ? CMS.demo.appointments
    : FALLBACK_APPTS;

  var appointments = seed.map(function (a, i) {
    return $.extend({ _id: 'appt_' + Date.now() + '_' + i }, a);
  });

  var cases = (CMS.demo && CMS.demo.cases && CMS.demo.cases.length)
    ? CMS.demo.cases
    : appointments.map(function (a) { return { id: a.caseId, name: a.patient }; });

  var state = { base: startOfDay(new Date()), activeDate: null, type: '', mode: '' };

  /* ------------------------------------------------------------------ *
   * Helpers
   * ------------------------------------------------------------------ */
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function fmtISO(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function startOfDay(d) { var x = new Date(d); x.setHours(0, 0, 0, 0); return x; }
  function addDays(d, n) { var x = new Date(d); x.setDate(x.getDate() + n); return x; }
  function startOfWeek(d) { var x = startOfDay(d); return addDays(x, -((x.getDay() + 6) % 7)); }

  var DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  function fmtShort(iso) {
    var p = String(iso || '').split('-');
    if (p.length !== 3) return iso || '';
    return (+p[2]) + ' ' + MONTHS[(+p[1]) - 1];
  }
  function timeToMin(t) {
    var m = /(\d+):(\d+)\s*(AM|PM)/i.exec(t || '');
    if (!m) return 0;
    var h = (+m[1]) % 12;
    if (/pm/i.test(m[3])) h += 12;
    return h * 60 + (+m[2]);
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function initials(name) {
    return CMS.initials ? CMS.initials(name) : String(name || '?').slice(0, 2).toUpperCase();
  }
  function initSelect2($el, opts) {
    if (!$el.length || !$.fn.select2 || $el.data('select2')) return;
    $el.select2($.extend({ width: '100%' }, opts || {}));
  }
  function normalizeDate(s) {
    s = $.trim(s || '');
    if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
    var d = new Date(s);
    return isNaN(d) ? fmtISO(new Date()) : fmtISO(d);
  }

  /* ------------------------------------------------------------------ *
   * Week strip
   * ------------------------------------------------------------------ */
  function renderWeek() {
    var mon = startOfWeek(state.base);
    var sun = addDays(mon, 6);
    $('#weekLabel').text(mon.getDate() + ' – ' + sun.getDate() + ' ' + MONTHS[sun.getMonth()] + ' ' + sun.getFullYear());
    var todayISO = fmtISO(new Date());
    var html = '';
    for (var i = 0; i < 7; i++) {
      var d = addDays(mon, i);
      var iso = fmtISO(d);
      var count = appointments.filter(function (a) { return a.date === iso; }).length;
      var cls = 'day-card' + (iso === todayISO ? ' today' : '') + (iso === state.activeDate ? ' active' : '');
      html += '<button type="button" class="' + cls + '" data-date="' + iso + '">' +
        '<span class="d">' + DAYS[i] + '</span>' +
        '<span class="n">' + d.getDate() + '</span>' +
        '<span class="c">' + count + ' appt' + (count === 1 ? '' : 's') + '</span></button>';
    }
    $('#weekStrip').html(html);
  }

  $('#weekStrip').on('click', '.day-card', function () {
    var iso = $(this).data('date');
    state.activeDate = (state.activeDate === iso) ? null : iso;
    renderWeek();
    renderList();
  });
  $('#weekPrev').on('click', function () { state.base = addDays(state.base, -7); renderWeek(); });
  $('#weekNext').on('click', function () { state.base = addDays(state.base, 7); renderWeek(); });

  /* ------------------------------------------------------------------ *
   * Appointment list
   * ------------------------------------------------------------------ */
  function filtered() {
    return appointments.filter(function (a) {
      if (state.activeDate && a.date !== state.activeDate) return false;
      if (state.type && a.type !== state.type) return false;
      if (state.mode && a.mode !== state.mode) return false;
      return true;
    }).sort(function (a, b) {
      if (a.date !== b.date) return a.date < b.date ? -1 : 1;
      return timeToMin(a.time) - timeToMin(b.time);
    });
  }

  function renderList() {
    var list = filtered();
    var $l = $('#apptList');
    $('#apptCount').text(list.length + ' appointment' + (list.length === 1 ? '' : 's') +
      (state.activeDate ? ' · ' + fmtShort(state.activeDate) : ''));
    if (!list.length) {
      $l.html('<div class="empty">No appointments match the current filters.</div>');
      return;
    }
    $l.html(list.map(function (a) {
      var tele = a.mode === 'Teleconsultation';
      return '<div class="appt" data-id="' + a._id + '">' +
        '<div class="tm"><strong>' + esc(a.time) + '</strong><span>' + esc(fmtShort(a.date)) + '</span></div>' +
        '<div class="avatar sm">' + esc(initials(a.patient)) + '</div>' +
        '<div class="grow"><div class="cell-main">' + esc(a.patient) + '</div>' +
        '<div class="hint">' + esc(a.caseId) + ' · ' + esc(a.type) + ' · ' + esc(a.location) + '</div></div>' +
        '<span class="mode-pill' + (tele ? ' tele' : '') + '">' + esc(a.mode) + '</span>' +
        '<div class="appt-actions">' +
        '<button type="button" class="btn btn-ghost btn-sm" data-act="resched">Reschedule</button>' +
        '<button type="button" class="btn btn-ghost btn-sm" data-act="cancel">Cancel</button>' +
        '</div></div>';
    }).join(''));
  }

  $('#apptList').on('click', '[data-act]', function () {
    var id = $(this).closest('.appt').data('id');
    var a = appointments.filter(function (x) { return x._id === id; })[0];
    if (!a) return;
    if ($(this).data('act') === 'cancel') {
      if (confirm('Cancel the appointment for ' + a.patient + ' on ' + fmtShort(a.date) + ' at ' + a.time + '?')) {
        appointments = appointments.filter(function (x) { return x._id !== id; });
        renderWeek();
        renderList();
        CMS.toast('Appointment cancelled', 'success');
      }
    } else {
      CMS.toast('Reschedule request sent for ' + a.patient, 'info');
    }
  });

  /* ------------------------------------------------------------------ *
   * Filters
   * ------------------------------------------------------------------ */
  $('#apptFilters').cmsFilters({
    filters: [
      { key: 'type', label: 'Type', type: 'select', placeholder: 'All Types',
        options: ['Psychological Session', 'Follow-up', 'Intake Assessment', 'Crisis Review', 'Safety Plan Review', 'Family Session'] },
      { key: 'mode', label: 'Mode', type: 'select', placeholder: 'All Modes',
        options: ['In-person', 'Teleconsultation'] }
    ],
    onChange: function (v) {
      state.type = v.type || '';
      state.mode = v.mode || '';
      renderList();
      updateFilterBadge();
    }
  });

  /* ------------------------------------------------------------------ *
   * Collapsible filter panel (funnel icon button)
   * ------------------------------------------------------------------ */
  function updateFilterBadge(){
    var st = $('#apptFilters').data('cmsfilters');
    var vals = st ? st.getValues() : {};
    var n = 0;
    $.each(vals, function(k, v){ if (v !== '' && v != null) n++; });
    $('#filterCount').text(n).prop('hidden', n === 0);
    $('#filterToggle').toggleClass('has-active', n > 0);
  }
  function setFilterPanel(open){
    var $p = $('#apptFilterPanel');
    $('#filterToggle').attr('aria-expanded', open ? 'true' : 'false');
    if (open){
      $p.prop('hidden', false).stop(true, true).hide().slideDown(220, function(){ $p.addClass('open'); });
    } else {
      $p.stop(true, true).slideUp(220, function(){ $p.prop('hidden', true).removeClass('open'); });
    }
  }
  $('#filterToggle').on('click', function(){
    setFilterPanel($('#apptFilterPanel').prop('hidden') || !$('#apptFilterPanel').is(':visible'));
  });
  $('#apptApplyFilters').on('click', function(){ setFilterPanel(false); });
  $('#apptClearFilters').on('click', function(){
    var st = $('#apptFilters').data('cmsfilters');
    if (st) st.reset();
    updateFilterBadge();
  });

  /* ------------------------------------------------------------------ *
   * Book modal
   * ------------------------------------------------------------------ */
  function openModal() { $('#bookModal').addClass('open'); }
  function closeModal() { $('#bookModal').removeClass('open'); }

  $('#bookBtn').on('click', openModal);
  $('#bookModal').on('click', '[data-close]', closeModal);
  $('#bookModal').on('click', function (e) { if (e.target === this) closeModal(); });
  $(document).on('keydown', function (e) { if (e.key === 'Escape') closeModal(); });

  var $pSel = $('#bkPatient');
  cases.forEach(function (c) {
    $pSel.append('<option value="' + esc(c.id) + '">' + esc(c.name) + ' · ' + esc(c.id) + '</option>');
  });
  initSelect2($pSel, { placeholder: 'Select patient', dropdownParent: $('#bookModal') });
  initSelect2($('#bkType'), { placeholder: 'Select type', dropdownParent: $('#bookModal') });

  $('#bookForm').on('submit', function (e) {
    e.preventDefault();
    var pText = $pSel.find('option:selected').text();
    var appt = {
      patient: (pText.split(' · ')[0] || pText),
      caseId: $pSel.val(),
      date: normalizeDate($('#bkDate').val()),
      time: $('#bkTime').val(),
      type: $('#bkType').val(),
      mode: $('input[name="bkMode"]:checked').val(),
      location: $('#bkLocation').val()
    };
    appointments.push($.extend({ _id: 'appt_' + Date.now() }, appt));
    state.activeDate = appt.date;
    this.reset();
    closeModal();
    renderWeek();
    renderList();
    CMS.toast('Appointment booked for ' + appt.patient, 'success');
  });

  /* ------------------------------------------------------------------ *
   * Init
   * ------------------------------------------------------------------ */
  renderWeek();
  renderList();
});
