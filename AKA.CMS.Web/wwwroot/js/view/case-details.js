/* ==========================================================================
   CMS · Case Details — js/view/case-details.js
   API-wired (no demo data):
     GET  /api/cases/{id}                  → header + overview
     GET  /api/screenings/case/{id}        → screenings tab
     GET  /api/referrals/case/{id}         → referrals tab
     POST /api/referrals                   → add referral
     GET  /api/case-comments/case/{id}     → clinical notes tab
     POST /api/case-comments               → add clinical note
     GET  /api/cases/{id}/history          → timeline tab
     PUT  /api/cases/{id}                  → edit priority / notes
   Case id comes from the ?id= query parameter.
   ========================================================================== */
$(function () {
  'use strict';

  var params = new URLSearchParams(window.location.search);
  var caseId = parseInt(params.get('id'), 10);
  if (!caseId) {
    CMS.toast('No case selected.', 'error');
    location.href = '/Cases';
    return;
  }

  var caseData = null; // CaseDto from GET /api/cases/{id}

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtDate(iso) {
    if (!iso) return '—';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return '—';
    return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
  }
  function fmtDateTime(iso) {
    if (!iso) return '—';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return '—';
    return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) +
      ' ' + d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  }

  /* ------------------------------------------------------------------ *
   * Tabs
   * ------------------------------------------------------------------ */
  $('#caseTabs').on('click', '.tab', function () {
    var key = $(this).data('tab');
    $('#caseTabs .tab').removeClass('active');
    $(this).addClass('active');
    $('.tab-panel').removeClass('active');
    $('.tab-panel[data-panel="' + key + '"]').addClass('active');
    if (key === 'screenings') loadScreenings();
    if (key === 'referrals') loadReferrals();
    if (key === 'timeline') loadTimeline();
    if (key === 'clinical') loadComments();
  });

  /* ------------------------------------------------------------------ *
   * Header + overview — GET /api/cases/{id}
   * ------------------------------------------------------------------ */
  function loadCase() {
    CMS.loader(true);
    cmsAjax({
      url: '/api/cases/' + caseId,
      method: 'GET',
      fallbackMsg: 'Could not load the case.',
      success: function (c) {
        CMS.loader(false);
        caseData = c;
        var name = c.memberName || 'Unknown patient';
        $('#cdAvatar').text(CMS.initials(name));
        $('#cdName').text(name);
        $('#cdId').text(c.caseNumber || ('#' + c.caseId));
        $('#cdBadges').html(
          '<span class="pill">' + esc(c.statusName || c.status) + '</span> ' +
          (c.priorityLevel ? '<span class="badge badge-moderate">' + esc(c.priorityLevel) + ' priority</span>' : '')
        );
        $('#cdKv').html(
          kv('Patient', name) +
          kv('MR Number', c.memberMrNo || '—') +
          kv('Source', c.sourceType || '—') +
          kv('Status', c.statusName || c.status) +
          kv('Current step', c.currentStep || '—') +
          kv('Assignee', c.assignedToUsername || 'Unassigned') +
          kv('Priority', c.priorityLevel || '—') +
          kv('Registered', fmtDate(c.createdAt))
        );
        loadMemberDetails(c.communityMemberId);
        $('#cdRiskSummary').html(
          '<p class="hint">Latest screening and workflow position appear here once screenings are recorded.</p>' +
          '<a class="btn btn-ghost btn-sm" href="/Screening?caseId=' + c.caseId + '">Open in Screening</a>'
        );
      },
      error: function (xhr) {
        CMS.loader(false);
        if (xhr && xhr.status === 404) location.href = '/Cases';
      }
    });
  }
  function kv(k, v) {
    return '<div><span class="k">' + esc(k) + '</span><div class="v">' + esc(v) + '</div></div>';
  }

  /* ------------------------------------------------------------------ *
   * Patient profile — GET /api/patients/members/{id}
   * ------------------------------------------------------------------ */
  function loadMemberDetails(memberId) {
    if (!memberId) return;
    cmsAjax({
      url: '/api/patients/members/' + memberId,
      method: 'GET',
      fallbackMsg: 'Could not load patient details.',
      success: function (m) {
        var html =
          kv('Age', m.age != null ? m.age : '—') +
          kv('Gender', m.gender || '—') +
          kv('Phone', m.phone || '—') +
          kv('Region council', m.regionCouncil || '—') +
          kv('Local council', m.localCouncil || '—') +
          kv('Village', m.village || '—') +
          kv('JK attend', m.jkAttend || '—') +
          kv('Employment / Education', m.employmentEducation || '—') +
          kv('Marital status', m.maritalStatus || '—') +
          kv('No. of children', m.numberOfChildren != null ? m.numberOfChildren : '—') +
          kv('Languages spoken', m.languagesSpoken || '—') +
          kv('Health insurance', m.healthInsurance || '—') +
          kv('GP / Usual care', m.gpUsualCare || '—') +
          kv('Prior MH treatment', m.priorMhTreatment || '—') +
          kv('Connected to MH care', m.connectedToMhCare || '—') +
          kv('Care provider', m.careProviderName || '—');
        $('#cdPatientKv').html(html);
      },
      error: function () { /* keep overview-only view if member cannot load */ }
    });
  }

  /* ------------------------------------------------------------------ *
   * Screenings tab — GET /api/screenings/case/{id}
   * ------------------------------------------------------------------ */
  var screeningsLoaded = false;
  function loadScreenings() {
    if (screeningsLoaded) return;
    screeningsLoaded = true;
    cmsAjax({
      url: '/api/screenings/case/' + caseId,
      method: 'GET',
      fallbackMsg: 'Could not load screenings.',
      success: function (rows) {
        var $tb = $('#screeningTable tbody').empty();
        if (!rows || !rows.length) {
          $tb.append('<tr><td colspan="5" class="hint" style="text-align:center">No screenings recorded yet.</td></tr>');
          return;
        }
        rows.forEach(function (s) {
          $tb.append(
            '<tr><td><div class="cell-main">' + esc(s.toolName || s.toolCode) + '</div></td>' +
            '<td>' + esc(String(s.rawScore != null ? s.rawScore : '—')) + '</td>' +
            '<td>' + esc(s.riskLevelName || s.riskLevel || '') + '</td>' +
            '<td>' + esc(fmtDate(s.screenedAt)) + '</td>' +
            '<td>' + esc(s.screenedByUsername || '') + '</td></tr>'
          );
        });
      },
      error: function () { screeningsLoaded = false; }
    });
  }

  /* ------------------------------------------------------------------ *
   * Referrals tab
   * ------------------------------------------------------------------ */
  var referralsLoaded = false;
  function loadReferrals() {
    if (referralsLoaded) return;
    referralsLoaded = true;
    cmsAjax({
      url: '/api/referrals/case/' + caseId,
      method: 'GET',
      fallbackMsg: 'Could not load referrals.',
      success: function (rows) {
        var $list = $('#referralList').empty();
        if (!rows || !rows.length) {
          $list.append('<p class="hint">No referrals yet.</p>');
          return;
        }
        rows.forEach(function (r) {
          $list.append(
            '<div class="ref-item"><div class="ref-top"><strong>' + esc(r.referredTo) + '</strong>' +
            '<span class="badge badge-moderate">' + esc(r.status) + '</span></div>' +
            (r.notes ? '<div class="cell-sub">' + esc(r.notes) + '</div>' : '') +
            '<div class="cell-sub muted">' + esc(r.referralNumber || '') + ' · ' +
            esc(fmtDate(r.createdAt)) + '</div></div>'
          );
        });
      },
      error: function () { referralsLoaded = false; }
    });
  }

  $('#referralForm').on('submit', function (e) {
    e.preventDefault();
    var to = $.trim($('#refTo').val());
    if (!to) { CMS.toast('Select where to refer.', 'error'); return; }
    cmsAjax({
      url: '/api/referrals',
      method: 'POST',
      json: true,
      data: { caseId: caseId, referredTo: to, notes: $.trim($('#refNotes').val()) || null },
      fallbackMsg: 'Could not add the referral.',
      success: function () {
        $('#refTo').val('').trigger('change');
        $('#refNotes').val('');
        referralsLoaded = false;
        loadReferrals();
        CMS.toast('Referral added.', 'success');
      }
    });
  });

  /* ------------------------------------------------------------------ *
   * Clinical tab — case comments
   * ------------------------------------------------------------------ */
  var commentsLoaded = false;
  function loadComments() {
    if (commentsLoaded) return;
    commentsLoaded = true;
    cmsAjax({
      url: '/api/case-comments/case/' + caseId,
      method: 'GET',
      fallbackMsg: 'Could not load clinical notes.',
      success: function (rows) {
        var $wrap = $('#clinicalNotesList');
        if (!$wrap.length) return;
        $wrap.empty();
        if (!rows || !rows.length) {
          $wrap.append('<p class="hint">No clinical notes yet.</p>');
          return;
        }
        rows.forEach(function (n) {
          $wrap.append(
            '<div class="note-item"><div class="hint">' +
            esc(n.createdByUsername || '') + ' · ' + esc(fmtDateTime(n.createdAt)) + '</div>' +
            '<p>' + esc(n.comment) + '</p></div>'
          );
        });
      },
      error: function () { commentsLoaded = false; }
    });
  }

  $('#saveNotesBtn').on('click', function () {
    var text = $.trim($('#clinicalNotes').val());
    if (!text) { CMS.toast('Write a note first.', 'error'); return; }
    cmsAjax({
      url: '/api/case-comments',
      method: 'POST',
      json: true,
      data: { caseId: caseId, commentType: 'NOTE', comment: text },
      fallbackMsg: 'Could not save the note.',
      success: function () {
        $('#clinicalNotes').val('');
        commentsLoaded = false;
        loadComments();
        CMS.toast('Clinical note saved.', 'success');
      }
    });
  });

  /* ------------------------------------------------------------------ *
   * Timeline tab — GET /api/cases/{id}/history
   * ------------------------------------------------------------------ */
  var timelineLoaded = false;
  function loadTimeline() {
    if (timelineLoaded) return;
    timelineLoaded = true;
    cmsAjax({
      url: '/api/cases/' + caseId + '/history',
      method: 'GET',
      fallbackMsg: 'Could not load the timeline.',
      success: function (rows) {
        var $tl = $('#caseTimeline').empty();
        if (!rows || !rows.length) {
          $tl.append('<p class="hint">No history yet.</p>');
          return;
        }
        rows.forEach(function (h) {
          $tl.append(
            '<div class="tl-item"><div class="tl-t">' +
            esc(h.actionCode || (h.fromState + ' → ' + h.toState)) + '</div>' +
            '<div class="tl-d">' + esc(h.performedByUsername || '') + ' · ' +
            esc(fmtDateTime(h.performedAt)) +
            (h.comment ? ' — ' + esc(h.comment) : '') + '</div></div>'
          );
        });
      },
      error: function () { timelineLoaded = false; }
    });
  }

  /* ------------------------------------------------------------------ *
   * Edit case — PUT /api/cases/{id} (priority + notes, RowVersion)
   * ------------------------------------------------------------------ */
  $('#editCaseBtn').on('click', function () {
    if (!caseData) return;
    $('#ecPriority').val(caseData.priorityLevel || '');
    $('#ecNotes').val(caseData.notes || '');
    $('#editCaseModal').addClass('open');
  });
  $('#editCaseModal').on('click', '[data-modal-close]', function () {
    $('#editCaseModal').removeClass('open');
  });
  $('#editCaseForm').on('submit', function (e) {
    e.preventDefault();
    if (!caseData) return;
    cmsAjax({
      url: '/api/cases/' + caseId,
      method: 'PUT',
      json: true,
      data: {
        priorityLevel: $('#ecPriority').val() || null,
        notes: $.trim($('#ecNotes').val()) || null,
        rowVersion: caseData.rowVersion
      },
      fallbackMsg: 'Could not update the case.',
      success: function () {
        $('#editCaseModal').removeClass('open');
        CMS.toast('Case updated.', 'success');
        loadCase();
      },
      error: function (xhr) {
        // 409 → someone else changed the case; reload for a fresh RowVersion.
        if (xhr && xhr.status === 409) loadCase();
      }
    });
  });

  CMS.initSelect2($('#caseDetailsWrap'));
  loadCase();
});
