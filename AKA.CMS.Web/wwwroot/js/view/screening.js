/* ==========================================================================
   CMS · Screening Tools — js/view/screening.js
   API-wired (no demo data):
     GET  /api/screenings/tools          → tool cards + risk bands
     POST /api/screenings/submit         → server-side scoring (201)
     GET  /api/screenings/case/{caseId}  → screening history for the case
   Questionnaires are rendered client-side from the bank below, keyed by
   the API ToolCode. Scoring is authoritative server-side — the result
   shown after submit comes from the API response.
   ========================================================================== */
$(function () {
  'use strict';

  /* ------------------------------------------------------------------ *
   * Question bank — loaded dynamically from /api/screening-tools/active.
   * Falls back to empty (tools without questions show a notice).
   * ------------------------------------------------------------------ */
  var QUESTIONS = {};
  var QUESTIONS_LOADED = false;

  function loadQuestions(done) {
    if (QUESTIONS_LOADED) { done(); return; }
    if (window.CMS_SCREEN_TOOLS) {
      CMS_SCREEN_TOOLS.load(function (tools) {
        tools.forEach(function (t) { QUESTIONS[t.code] = t.questions || []; });
        QUESTIONS_LOADED = true;
        done();
      });
    } else {
      QUESTIONS_LOADED = true;
      done();
    }
  }


  /* ------------------------------------------------------------------ *
   * Helpers
   * ------------------------------------------------------------------ */
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtDate(iso) {
    if (!iso) return '—';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return esc(iso);
    return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
  }
  function badgeClass(toolCode, riskLevel) {
    var r = String(riskLevel || '').toUpperCase();
    if (r === 'MINIMAL' || r === 'MILD') return 'badge-low';
    if (r === 'MODERATE') return 'badge-moderate';
    if (r === 'MOD_SEVERE') return 'badge-high';
    if (r === 'SEVERE') return (toolCode === 'SBQR' || toolCode === 'CSSRS') ? 'badge-crisis' : 'badge-high';
    return 'badge-low';
  }
  function caseId() {
    var v = parseInt($('#caseSelect').val(), 10);
    return v > 0 ? v : 0;
  }

  var toolsByCode = {};
  var currentTool = null;

  function bandColor(code) {
    switch (String(code || '').toUpperCase()) {
      case 'MINIMAL':
      case 'MILD': return 'var(--green)';
      case 'MODERATE': return 'var(--amber)';
      case 'MOD_SEVERE': return 'var(--orange)';
      case 'SEVERE': return 'var(--red)';
      default: return 'var(--muted)';
    }
  }

  var TOOL_ICON = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4a3 3 0 0 1 6 0M9.5 13l2 2 3.5-4"/></svg>';

  /* ------------------------------------------------------------------ *
   * Tool cards — GET /api/screenings/tools
   * ------------------------------------------------------------------ */
  function loadTools() {
    cmsAjax({
      url: '/api/screenings/tools',
      method: 'GET',
      fallbackMsg: 'Could not load screening tools.',
      success: function (tools) {
        toolsByCode = {};
        var $grid = $('#toolGrid').empty();
        if (!tools || !tools.length) {
          $grid.append('<div class="card"><div class="card-body"><p class="hint">No screening tools are configured.</p></div></div>');
          return;
        }
        tools.forEach(function (t) {
          var code = String(t.toolCode || '').toUpperCase();
          toolsByCode[code] = t;
          var bands = (t.bands || []).map(function (b) {
            return '<span class="tband"><i style="background:' + bandColor(b.bandCode) + '"></i>' +
              esc(b.bandName) + ' <b>' + b.minScore + '–' + b.maxScore + '</b></span>';
          }).join('');
          var hasQuestions = !!QUESTIONS[code];
          $grid.append(
            '<div class="card tool-card"><div class="card-body">' +
            '<div class="tool-top">' +
            '<span class="tool-ic">' + TOOL_ICON + '</span>' +
            '<div class="tool-id"><h3>' + esc(code) + '</h3>' +
            '<p class="hint">' + esc(t.toolName || '') + '</p></div>' +
            '<span class="tool-items">' + t.itemCount + ' items</span>' +
            '</div>' +
            (bands ? '<div class="tool-bands">' + bands + '</div>' : '') +
            (hasQuestions
              ? '<button type="button" class="btn btn-primary btn-sm btn-block" data-open-tool="' + esc(code) + '">Start Assessment</button>'
              : '<p class="hint">Questionnaire not available for this tool yet.</p>') +
            '</div></div>'
          );
        });
      }
    });
  }

  $('#toolGrid').on('click', '[data-open-tool]', function () {
    openAssessment($(this).data('open-tool'));
  });

  /* ------------------------------------------------------------------ *
   * Assessment modal
   * ------------------------------------------------------------------ */
  var $modal = $('#screenModal');

  function footDefault() {
    $('#smFoot').html(
      '<button class="btn btn-ghost" data-modal-close type="button">Cancel</button>' +
      '<button class="btn btn-primary" id="smSubmit" type="button">Submit Assessment</button>'
    );
  }

  function openAssessment(code) {
    var tool = toolsByCode[code];
    var questions = QUESTIONS[code];
    if (!tool || !questions) return;
    currentTool = { code: code, tool: tool, questions: questions };

    $('#smTitle').text((tool.toolName || code) + ' Assessment');
    $('#smSub').text((tool.description || '') + ' · ' + tool.itemCount + ' items');
    $('#smResult').empty().hide();
    footDefault();

    var html = questions.map(function (q, qi) {
      var opts = q.options.map(function (o) {
        return '<label class="opt-row">' +
          '<input type="radio" name="sm_q' + qi + '" value="' + o.v + '">' +
          '<span class="ov">' + esc(String(o.v)) + '</span>' +
          '<span>' + esc(o.t) + '</span></label>';
      }).join('');
      return '<div class="screen-q" data-q="' + qi + '">' +
        '<p><span class="qn">Q' + (qi + 1) + '</span>' + esc(q.text) + '</p>' +
        '<div class="opt-rows">' + opts + '</div></div>';
    }).join('');
    $('#smQuestions').html(html).show();

    if (window.CMS && typeof CMS.initSelect2 === 'function') CMS.initSelect2($modal);
    $modal.addClass('open');
  }

  $modal.on('click', '[data-modal-close]', function () { $modal.removeClass('open'); });

  $modal.on('change', '.opt-row input[type="radio"]', function () {
    var $rows = $(this).closest('.opt-rows');
    $rows.find('.opt-row').removeClass('sel');
    $(this).closest('.opt-row').addClass('sel');
    $(this).closest('.screen-q').removeClass('unanswered');
  });

  function collectAnswers() {
    var questions = currentTool.questions, answers = [], ok = true, firstBad = null;
    questions.forEach(function (q, qi) {
      var $q = $('#smQuestions .screen-q[data-q="' + qi + '"]');
      var $checked = $q.find('input[type="radio"]:checked');
      if (!$checked.length) {
        ok = false;
        $q.addClass('unanswered');
        if (!firstBad) firstBad = $q;
      }
      answers.push(parseInt($checked.val(), 10) || 0);
    });
    return { ok: ok, answers: answers, firstBad: firstBad };
  }

  function renderResult(resp) {
    var s = resp.screening || {};
    var tool = currentTool.tool;
    var sub = '';
    if (s.subscaleScoresJson) {
      try {
        var subs = JSON.parse(s.subscaleScoresJson);
        var parts = Object.keys(subs).map(function (k) {
          return '<div class="sub"><strong>' + esc(String(subs[k])) + '</strong><span>' + esc(k) + '</span></div>';
        });
        if (parts.length) sub = '<div class="screen-subscales">' + parts.join('') + '</div>';
      } catch (e) { /* ignore malformed subscales */ }
    }
    var severity = s.riskLevelName || s.riskLevel || '';
    $('#smQuestions').hide();
    $('#smResult').html(
      '<div class="screen-result">' +
      '<div class="score-num">' + esc(String(s.rawScore != null ? s.rawScore : '—')) +
      '<span> / ' + esc(String(tool.maxScore != null ? tool.maxScore : '')) + '</span></div>' +
      '<div class="score-badges"><span class="badge ' + badgeClass(currentTool.code, s.riskLevel) + '">' +
      esc(severity) + '</span></div>' +
      '<p class="hint" style="font-size:13px;color:var(--text)">Scored server-side and saved to case #' +
      esc(String(s.caseId)) + '.</p>' +
      (resp.autoTransitionNote ? '<p class="hint">' + esc(resp.autoTransitionNote) + '</p>' : '') +
      sub +
      '</div>'
    ).show();
    $('#smFoot').html(
      '<button class="btn btn-ghost" id="smBack" type="button">Back to Questions</button>' +
      '<button class="btn btn-accent" id="smDone" type="button">Done</button>'
    );
  }

  $('#smFoot').on('click', '#smSubmit', function () {
    if (!currentTool) return;
    var id = caseId();
    if (!id) {
      CMS.toast('Please select a case from the picker first.', 'error');
      $caseSelect.select2('open');
      return;
    }
    var c = collectAnswers();
    if (!c.ok) {
      CMS.toast('Please answer all questions before submitting.', 'error');
      if (c.firstBad && c.firstBad[0] && c.firstBad[0].scrollIntoView) {
        c.firstBad[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
      return;
    }
    CMS.loader(true);
    cmsAjax({
      url: '/api/screenings/submit',
      method: 'POST',
      json: true,
      data: { caseId: id, toolCode: currentTool.code, itemScores: c.answers },
      fallbackMsg: 'Could not submit the screening.',
      success: function (resp) {
        CMS.loader(false);
        renderResult(resp);
        CMS.toast((currentTool.tool.toolName || currentTool.code) + ' submitted — scored ' +
          resp.screening.rawScore + ' (' + (resp.screening.riskLevelName || resp.screening.riskLevel) + ')', 'success');
      },
      error: function () { CMS.loader(false); }
    });
  });

  $('#smFoot').on('click', '#smBack', function () {
    $('#smResult').empty().hide();
    $('#smQuestions').show();
    footDefault();
  });

  $('#smFoot').on('click', '#smDone', function () {
    $modal.removeClass('open');
    loadCaseScreenings();
  });

  /* ------------------------------------------------------------------ *
   * Case screenings — GET /api/screenings/case/{caseId}
   * ------------------------------------------------------------------ */
  function loadCaseScreenings() {
    var id = caseId();
    if (!id) {
      CMS.toast('Select a case from the picker first.', 'error');
      $caseSelect.select2('open');
      return;
    }
    cmsAjax({
      url: '/api/screenings/case/' + id,
      method: 'GET',
      fallbackMsg: 'Could not load screenings for this case.',
      success: function (rows) {
        var $tb = $('#screenTable tbody').empty();
        $('#screenCount').text(rows && rows.length ? rows.length + ' recorded' : 'None recorded');
        $('#caseHint').text(rows && rows.length ? '' : 'No screenings recorded for case #' + id + ' yet.');
        if (!rows || !rows.length) {
          $tb.append('<tr><td colspan="5" class="hint" style="text-align:center">No screenings recorded for this case yet.</td></tr>');
          return;
        }
        rows.forEach(function (s) {
          $tb.append(
            '<tr><td><div class="cell-main">' + esc(s.toolName || s.toolCode) + '</div>' +
            '<div class="cell-sub">' + esc(s.toolCode || '') + '</div></td>' +
            '<td>' + esc(String(s.rawScore != null ? s.rawScore : '—')) + '</td>' +
            '<td><span class="badge ' + badgeClass(s.toolCode, s.riskLevel) + '">' +
            esc(s.riskLevelName || s.riskLevel || '') + '</span></td>' +
            '<td>' + esc(fmtDate(s.screenedAt)) + '</td>' +
            '<td>' + esc(s.screenedByUsername || ('#' + s.screenedBy)) + '</td></tr>'
          );
        });
      }
    });
  }

  /* ------------------------------------------------------------------ *
   * Case picker — GET /api/cases (paged, searchable)
   * ------------------------------------------------------------------ */
  var $caseSelect = $('#caseSelect');
  $caseSelect.select2({
    placeholder: 'Search case by number, patient name, or MR…',
    minimumInputLength: 0,
    width: '100%',
    ajax: {
      transport: function (params, success, failure) {
        cmsAjax({
          url: '/api/cases',
          method: 'GET',
          data: { search: params.data.term || '', page: params.data.page || 1, pageSize: 20 },
          fallbackMsg: 'Could not load cases.',
          success: success,
          error: function (xhr) { failure(xhr); }
        });
      },
      processResults: function (res, params) {
        params.page = params.page || 1;
        var items = (res && res.items) || [];
        return {
          results: items.map(function (c) {
            return {
              id: c.caseId,
              text: (c.caseNumber || ('#' + c.caseId)) + ' · ' +
                    (c.memberName || 'Unknown patient') +
                    (c.memberMrNo ? ' (' + c.memberMrNo + ')' : '') +
                    ' — ' + (c.statusName || c.status)
            };
          }),
          pagination: { more: (params.page * 20) < ((res && res.totalCount) || 0) }
        };
      }
    }
  });

  $caseSelect.on('change', function () {
    if (caseId()) loadCaseScreenings();
  });

  /* ------------------------------------------------------------------ *
   * init
   * ------------------------------------------------------------------ */
  loadQuestions(function () { loadTools(); });

  // Preselect a case when arriving from Register New Case (?caseId=).
  (function preselectCase() {
    var preset = parseInt(new URLSearchParams(window.location.search).get('caseId'), 10);
    if (!preset) return;
    cmsAjax({
      url: '/api/cases/' + preset,
      method: 'GET',
      success: function (c) {
        var label = (c.caseNumber || ('#' + c.caseId)) + ' · ' +
          (c.memberName || 'Unknown patient') +
          (c.memberMrNo ? ' (' + c.memberMrNo + ')' : '') +
          ' — ' + (c.statusName || c.status);
        var opt = new Option(label, c.caseId, true, true);
        $caseSelect.append(opt).trigger('change');
      },
      error: function () { return true; } // stay silent; user can pick manually
    });
  })();
});
