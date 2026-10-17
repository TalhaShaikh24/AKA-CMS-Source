/* ==========================================================================
   CMS · Case Details — js/view/case-details.js
   Matches the CMO design: Patient Information / Current Service /
   Case Actions cards + Current Risk alert + Recent Timeline.
   API-wired (no demo data):
     GET  /api/cases/{id}               → header + cards
     GET  /api/patients/members/{id}    → patient details
     GET  /api/cases/{id}/history       → recent timeline
     PUT  /api/cases/{id}               → edit priority / notes
   Case id comes from the ?id= query parameter.
   ========================================================================== */
$(function () {
  'use strict';
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);

  var params = new URLSearchParams(window.location.search);
  var caseId = parseInt(params.get('id'), 10);
  if (!caseId) {
    CMS.toast('No case selected.', 'error');
    location.href = '/Cases';
    return;
  }

  var caseData = null;

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
      ' · ' + d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  }
  function kv(k, v) { return '<div class="k">' + esc(k) + '</div><div class="v">' + esc(v == null || v === '' ? '—' : v) + '</div>'; }

  $('[data-go-crisis]').on('click', function () { location.href = '/Crisis/Case/' + caseId; });
  $('[data-go-timeline]').on('click', function () { location.href = '/Cases/Timeline?id=' + caseId; });
  $('[data-go]').on('click', function () { location.href = $(this).data('go'); });

  /* ---------- case ---------- */
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
        $('#cdSub').text(name + ' · ' + (c.caseNumber || ('#' + c.caseId)));
        $('#cdPatientKv').html(
          kv('Name', name) +
          kv('Age', c.memberAge != null ? c.memberAge + ' years' : null) +
          kv('Gender', c.memberGender) +
          kv('Location', c.memberVillage) +
          kv('Referral Source', c.sourceType) +
          kv('Referral On', fmtDate(c.createdAt))
        );
        $('#cdServiceKv').html(
          kv('Provider', c.assignedToUsername || 'Unassigned') +
          kv('Status', c.statusName || c.status)
        );
        var risk = c.priorityLevel || '—';
        var isHigh = /high|critical/i.test(risk);
        $('#cdRiskBox').html(
          '<div class="alert"><strong>' + esc(risk) + ' Risk</strong>' +
          (isHigh ? 'Active crisis indicators require assessment and immediate safety review.'
                  : 'Risk level recorded for this case.') + '</div>'
        );
        if (c.communityMemberId) loadMemberDetails(c.communityMemberId);
        loadTimeline();
        loadScreenings();
        loadRiskAssessment();
      },
      error: function (xhr) {
        CMS.loader(false);
        if (xhr && xhr.status === 404) location.href = '/Cases';
      }
    });
  }

  function loadRiskAssessment() {
    cmsAjax({
      url: '/api/cases/' + caseId + '/risk-assessment', method: 'GET',
      fallbackMsg: null,
      success: function (r) {
        if (!r) { $('#cdRiskAssessmentKv').html('<div class="hint">No risk assessment recorded.</div>'); return; }
        $('#cdRiskAssessmentKv').html(
          kv('Presenting Concern', r.presentingConcern) +
          kv('Primary MH Issue', r.primaryMhIssue) +
          kv('Is Crisis', r.isCrisis) +
          kv('Crisis Type', r.crisisType) +
          kv('Risk Category', r.riskCategory) +
          kv('Suicidal Ideation', r.suicidalIdeation) +
          kv('Self-Harm Risk', r.selfHarmRisk) +
          kv('Violence Risk', r.violenceRisk) +
          kv('Severity & Immediacy', r.severityImmediacy) +
          kv('Access to Means', r.accessToMeans) +
          kv('Safety Plan Filled', r.safetyPlanFilled) +
          kv('Social Determinants', r.socialDeterminantIssues) +
          kv('Supervisor Notified', r.supervisorNotified) +
          kv('Assessor', r.assessorName)
        );
      },
      error: function () { $('#cdRiskAssessmentKv').html('<div class="hint">No risk assessment recorded.</div>'); }
    });
  }

  function loadScreenings() {
    cmsAjax({
      url: '/api/screenings/case/' + caseId, method: 'GET',
      fallbackMsg: 'Could not load screening results.',
      success: function (list) {
        list = list || [];
        if (!list.length) {
          $('#cdScreenings').html('<div class="empty">No screenings recorded yet. <a href="/Screening?caseId=' + caseId + '">Start a screening</a></div>');
          return;
        }
        $('#cdScreenings').html(list.map(function (s) {
          var badge = 'badge-low';
          var rl = String(s.riskLevelName || s.riskLevel || '').toUpperCase();
          if (rl.indexOf('MODERATE') >= 0) badge = 'badge-moderate';
          else if (rl.indexOf('HIGH') >= 0 || rl.indexOf('SEVERE') >= 0) badge = 'badge-high';
          if (rl.indexOf('CRISIS') >= 0) badge = 'badge-crisis';
          return '<div class="geo-card" style="margin-bottom:10px">' +
            '<div class="geo-card-main"><div class="geo-card-name">' + esc(s.toolName || s.toolCode) + '</div>' +
            '<div class="geo-card-sub">Score: ' + esc(s.rawScore) + ' · ' + esc(s.completedAt ? new Date(s.completedAt).toLocaleDateString() : '') + '</div></div>' +
            '<div class="geo-card-side"><span class="badge ' + badge + '">' + esc(s.riskLevelName || s.riskLevel || '') + '</span>' +
            '<button class="btn btn-ghost btn-sm" data-edit-screening="' + s.screeningId + '" data-permission="Screenings:Write" type="button">Edit</button></div>' +
            '</div>';
        }).join(''));
        window._cdScreenings = list;
      },
      error: function () { $('#cdScreenings').html('<div class="empty">Could not load screening results.</div>'); }
    });
  }

  function loadMemberDetails(memberId) {
    cmsAjax({
      url: '/api/patients/members/' + memberId,
      method: 'GET',
      success: function (m) {
        var loc = [m.village, m.localCouncil, m.regionCouncil].filter(function (x) { return x; }).join(', ');
        var name = [m.firstName, m.lastName].filter(function (x) { return x; }).join(' ') || m.fullName;
        $('#cdPatientKv').html(
          kv('Name', name) +
          kv('Age', m.age != null ? m.age + ' years' : null) +
          kv('Gender', m.gender) +
          kv('Location', loc || null) +
          kv('Phone', m.phone) +
          kv('Date of Call', fmtDate(m.dateOfCall)) +
          kv('Entry Point', m.entryPoint) +
          kv('Consent', m.consentToProceed) +
          kv('Marital Status', m.maritalStatus) +
          kv('Prior MH Treatment', m.priorMhTreatment)
        );
      },
      error: function () { /* keep case-level data */ }
    });
  }

  /* ---------- recent timeline ---------- */
  function loadTimeline() {
    cmsAjax({
      url: '/api/cases/' + caseId + '/history',
      method: 'GET',
      success: function (rows) {
        var list = (rows || []).slice(0, 5);
        if (!list.length) { $('#cdTimeline').html('<div class="empty">No activity yet.</div>'); return; }
        $('#cdTimeline').html(list.map(function (h) {
          return '<div class="event"><h4>' + esc(h.actionName || h.actionCode || (h.fromState + ' → ' + h.toState)) + '</h4>' +
            '<p>' + esc(fmtDateTime(h.performedAt)) + (h.performedByUsername ? ' · ' + esc(h.performedByUsername) : '') + '</p></div>';
        }).join(''));
      },
      error: function () { $('#cdTimeline').html('<div class="empty">Could not load timeline.</div>'); }
    });
  }

  /* ---------- edit case ---------- */
  $('#editCaseBtn').on('click', function () {
    if (!caseData) return;
    $('#ecPriority').val(caseData.priorityLevel || '').trigger('change');
    $('#ecNotes').val(caseData.notes || '');
    $('#editCaseModal').addClass('open');
  });

  $('#editCaseForm').cmsValidate({
    onValid: function () {
      cmsAjax({
        url: '/api/cases/' + caseId,
        method: 'PUT',
        json: true,
        data: {
          priorityLevel: $('#ecPriority').val() || null,
          notes: $('#ecNotes').val() || null,
          rowVersion: caseData.rowVersion
        },
        fallbackMsg: 'Could not save the case.',
        success: function () {
          CMS.toast('Case updated.', 'success');
          $('#editCaseModal').removeClass('open');
          loadCase();
        }
      });
    }
  });

  /* ---------- edit screening ---------- */
  var editingScreening = null;

  $(document).on('click', '[data-edit-screening]', function () {
    var id = parseInt($(this).data('edit-screening'), 10);
    var list = window._cdScreenings || [];
    var s = list.filter(function (x) { return x.screeningId === id; })[0];
    if (!s) return;
    // Ensure dynamic questions are loaded before opening the editor.
    var openEditor = function () {
      editingScreening = s;
      var qs = (window.CMS_SCREEN_QUESTIONS || {})[s.toolCode] || [];
      $('#esTitle').text('Edit ' + (s.toolName || s.toolCode));
      var html = '';
    qs.forEach(function (q, qi) {
      var cur = (s.itemScores || [])[qi];
      html += '<div class="field" data-q="' + qi + '" style="margin-bottom:14px"><label>' + (qi + 1) + '. ' + esc(q.text) + ' *</label>';
      html += '<div class="seg" data-seg="esq' + qi + '">';
      q.options.forEach(function (o) {
        html += '<button type="button" data-val="' + o.v + '"' + (cur === o.v ? ' class="sel"' : '') + '>' + esc(o.t) + '</button>';
      });
      html += '</div><span class="field-error">Please answer this question.</span></div>';
    });
    $('#esQuestions').html(html);
    $('#editScreeningModal').addClass('open');
    };
    if (window.CMS_SCREEN_TOOLS) {
      CMS_SCREEN_TOOLS.load(function () { openEditor(); });
    } else {
      openEditor();
    }
  });

  $('#esSave').on('click', function () {
    if (!editingScreening) return;
    var qs = ((window.CMS_SCREEN_QUESTIONS || {})[editingScreening.toolCode] || []);
    var answers = [], ok = true;
    qs.forEach(function (q, qi) {
      var $f = $('#esQuestions .field[data-q="' + qi + '"]');
      var v = $f.find('.seg button.sel').data('val');
      if (v === undefined) { $f.addClass('invalid'); ok = false; }
      else { $f.removeClass('invalid'); answers.push(parseInt(v, 10)); }
    });
    if (!ok) { CMS.toast('Please answer all questions.', 'error'); return; }
    CMS.loader(true);
    cmsAjax({
      url: '/api/screenings/' + editingScreening.screeningId,
      method: 'PUT',
      json: true,
      data: { itemScores: answers, rowVersion: editingScreening.rowVersion },
      fallbackMsg: 'Could not update the screening.',
      success: function () {
        CMS.loader(false);
        CMS.toast('Screening updated.', 'success');
        $('#editScreeningModal').removeClass('open');
        editingScreening = null;
        loadScreenings();
      },
      error: function () { CMS.loader(false); }
    });
  });

  loadCase();
});
