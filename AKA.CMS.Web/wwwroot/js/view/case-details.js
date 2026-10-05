/* Case Details — demo-only port of the template view script — no API calls. Renders from CMS.demo / localStorage. */
$(function () {
  CMS.initSelect2($('#caseDetailsWrap'));

  // ---- Resolve case from ?id= (default: first) ----
  var cases = CMS.demo.cases || [];
  var params = new URLSearchParams(window.location.search);
  var caseId = params.get('id');
  var c = cases.filter(function (x) { return String(x.id) === String(caseId); })[0] || cases[0];
  if (!c) { $('#caseDetailsWrap').html('<div class="empty">No case found.</div>'); return; }

  // ---- Header ----
  $('#cdAvatar').text(CMS.initials(c.name));
  $('#cdName').text(c.name);
  $('#cdId').text(c.id);
  $('#cdBadges').html(CMS.riskBadge(c.risk) + ' ' + CMS.statusPill(c.status));

  $('#editCaseBtn').on('click', function () {
    CMS.toast('Edit case is coming soon in this demo.', 'info');
  });

  // ---- Tabs ----
  $('#caseTabs').on('click', '.tab', function () {
    var key = $(this).data('tab');
    $('#caseTabs .tab').removeClass('active');
    $(this).addClass('active');
    $('.tab-panel').removeClass('active');
    $('.tab-panel[data-panel="' + key + '"]').addClass('active');
  });

  // ---- Overview: patient information ----
  var kv = [
    ['Age', c.age], ['Gender', c.gender], ['Phone', '+92 355 501 22 44'],
    ['Region council', c.location], ['Local council', 'Central'],
    ['Village', 'Karimabad'], ['Language', 'Burushaski'],
    ['GP', 'Dr. Naveed Shah'], ['Insurance', 'Sehat Card — Yes'],
    ['Marital status', 'Married'], ['Prior MH treatment', 'No']
  ];
  var $kv = $('#cdKv').empty();
  $.each(kv, function (i, pair) {
    $kv.append('<div class="kv"><span class="k"></span><span class="v"></span></div>')
      .find('.kv').last().find('.k').text(pair[0]).end().end().find('.v').text(pair[1]);
  });

  // ---- Overview: risk summary ----
  var riskNote = {
    low: 'Routine monitoring. Next review in 90 days.',
    moderate: 'Monthly check-ins scheduled. Coping plan reviewed.',
    high: 'Weekly contact. Safety plan active and reviewed with family.',
    crisis: 'Immediate safety protocol in place. Crisis team on standby.'
  };
  $('#cdRiskSummary').html(
    '<div class="risk-summary-row">' + CMS.riskBadge(c.risk) + '</div>' +
    '<p class="sub">' + $('<div>').text(riskNote[c.risk] || '').html() + '</p>' +
    '<div class="kv"><span class="k">Assigned to</span><span class="v">' + $('<div>').text(c.assignee).html() + '</span></div>' +
    '<div class="kv"><span class="k">Last updated</span><span class="v">' + $('<div>').text(c.updated).html() + '</span></div>'
  );

  // ---- Clinical assessment notes (localStorage) ----
  var notesKey = 'cms_notes_' + c.id;
  $('#clinicalNotes').val(localStorage.getItem(notesKey) || '');
  $('#saveNotesBtn').on('click', function () {
    localStorage.setItem(notesKey, $('#clinicalNotes').val());
    CMS.toast('Clinical notes saved.', 'success');
  });

  // ---- Screenings table ----
  var screenings = [
    { tool: 'PHQ-9', score: 14, sev: 'Moderate', date: 'Sep 18, 2026', by: 'Ayesha Khan' },
    { tool: 'GAD-7', score: 11, sev: 'Moderate', date: 'Sep 18, 2026', by: 'Ayesha Khan' },
    { tool: 'SBQ-R', score: 9, sev: 'Elevated', date: 'Sep 04, 2026', by: 'Bilal Ahmed' }
  ];
  var $st = $('#screeningTable tbody').empty();
  $.each(screenings, function (i, s) {
    $st.append('<tr><td class="cell-main">' + $('<div>').text(s.tool).html() + '</td><td>' + s.score +
      '</td><td>' + $('<div>').text(s.sev).html() + '</td><td class="muted">' + $('<div>').text(s.date).html() +
      '</td><td>' + $('<div>').text(s.by).html() + '</td></tr>');
  });

  // ---- Referrals ----
  var referrals = [
    { to: 'Clinical Psychologist', date: 'Sep 20, 2026', note: 'CBT referral for depressive symptoms.', status: 'Pending' },
    { to: 'Community Health Worker', date: 'Aug 30, 2026', note: 'Home visit schedule confirmed.', status: 'Completed' }
  ];
  function renderReferrals() {
    var $list = $('#referralList').empty();
    $.each(referrals, function (i, r) {
      $list.append(
        '<div class="ref-item"><div class="ref-top"><strong>' + $('<div>').text(r.to).html() + '</strong>' +
        '<span class="badge ' + (r.status === 'Completed' ? 'badge-low' : 'badge-moderate') + '">' + r.status + '</span></div>' +
        '<div class="cell-sub">' + $('<div>').text(r.note).html() + '</div>' +
        '<div class="cell-sub muted">' + $('<div>').text(r.date).html() + '</div></div>'
      );
    });
  }
  renderReferrals();

  $('#referralForm').cmsValidate({
    onValid: function () {
      referrals.push({
        to: $('#refTo option:selected').text() || $('#refTo').val(),
        date: CMS.todayStr(),
        note: $('#refNotes').val() || '—',
        status: 'Pending'
      });
      renderReferrals();
      $('#referralForm')[0].reset();
      $('#refTo').val('').trigger('change');
      CMS.toast('Referral added.', 'success');
    }
  });

  // ---- Timeline ----
  var timeline = [
    { t: 'Case registered', d: 'Intake completed by Ayesha Khan · Sep 02, 2026' },
    { t: 'PHQ-9 screening', d: 'Score 14 (Moderate) · Sep 18, 2026' },
    { t: 'Referred to Clinical Psychologist', d: 'Pending · Sep 20, 2026' },
    { t: 'Follow-up due', d: 'Scheduled · Oct 02, 2026' }
  ];
  var $tl = $('#caseTimeline').empty();
  $.each(timeline, function (i, e) {
    $tl.append('<div class="tl-item"><div class="tl-t">' + $('<div>').text(e.t).html() +
      '</div><div class="tl-d">' + $('<div>').text(e.d).html() + '</div></div>');
  });
});
