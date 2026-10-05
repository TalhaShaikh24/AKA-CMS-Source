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
   * Question bank (published item texts; values match the server-side
   * per-tool ranges enforced by the screening stored procedure)
   * ------------------------------------------------------------------ */
  var A_PG = [ // PHQ-9 / GAD-7 anchors (0-3)
    { t: 'Not at all', v: 0 },
    { t: 'Several days', v: 1 },
    { t: 'More than half the days', v: 2 },
    { t: 'Nearly every day', v: 3 }
  ];
  var A_DASS = [ // DASS-21 anchors (0-3)
    { t: 'Did not apply to me at all', v: 0 },
    { t: 'Applied to me to some degree, or some of the time', v: 1 },
    { t: 'Applied to me to a considerable degree, or a good part of time', v: 2 },
    { t: 'Applied to me very much, or most of the time', v: 3 }
  ];
  var A_YN = [{ t: 'No', v: 0 }, { t: 'Yes', v: 1 }];

  function std(text, anchors) { return { text: text, options: anchors || A_PG }; }

  var QUESTIONS = {
    PHQ9: [
      std('Little interest or pleasure in doing things'),
      std('Feeling down, depressed, or hopeless'),
      std('Trouble falling or staying asleep, or sleeping too much'),
      std('Feeling tired or having little energy'),
      std('Poor appetite or overeating'),
      std('Feeling bad about yourself — or that you are a failure or have let yourself or your family down'),
      std('Trouble concentrating on things, such as reading the newspaper or watching television'),
      std('Moving or speaking so slowly that other people could have noticed — or the opposite, being so fidgety or restless that you have been moving around a lot more than usual'),
      std('Thoughts that you would be better off dead, or of hurting yourself in some way')
    ],
    GAD7: [
      std('Feeling nervous, anxious, or on edge'),
      std('Not being able to stop or control worrying'),
      std('Worrying too much about different things'),
      std('Trouble relaxing'),
      std('Being so restless that it is hard to sit still'),
      std('Becoming easily annoyed or irritable'),
      std('Feeling afraid as if something awful might happen')
    ],
    DASS21: [
      std('I found it hard to wind down', A_DASS),
      std('I was aware of dryness of my mouth', A_DASS),
      std("I couldn't seem to experience any positive feeling at all", A_DASS),
      std('I experienced breathing difficulty (e.g. excessively rapid breathing, breathlessness in the absence of physical exertion)', A_DASS),
      std('I found it difficult to work up the initiative to do things', A_DASS),
      std('I tended to over-react to situations', A_DASS),
      std('I experienced trembling (e.g. in the hands)', A_DASS),
      std('I felt that I was using a lot of nervous energy', A_DASS),
      std('I was worried about situations in which I might panic and make a fool of myself', A_DASS),
      std('I felt that I had nothing to look forward to', A_DASS),
      std('I found myself getting agitated', A_DASS),
      std('I found it difficult to relax', A_DASS),
      std('I felt down-hearted and blue', A_DASS),
      std('I was intolerant of anything that kept me from getting on with what I was doing', A_DASS),
      std('I felt I was close to panic', A_DASS),
      std('I was unable to become enthusiastic about anything', A_DASS),
      std("I felt I wasn't worth much as a person", A_DASS),
      std('I felt that I was rather touchy', A_DASS),
      std('I was aware of the action of my heart in the absence of physical exertion (e.g. sense of heart rate increase, heart missing a beat)', A_DASS),
      std('I felt scared without any good reason', A_DASS),
      std('I felt that life was meaningless', A_DASS)
    ],
    SBQR: [
      { text: 'Have you ever thought about or attempted to kill yourself?', options: [
        { t: 'Never', v: 1 },
        { t: 'It was just a brief passing thought', v: 2 },
        { t: 'I have had a plan at least once to kill myself but did not try to do it or work it out', v: 3 },
        { t: 'I have attempted to kill myself, but did not want to die', v: 4 },
        { t: 'I have attempted to kill myself, and really hoped to die', v: 4 }
      ]},
      { text: 'How often have you thought about killing yourself in the past year?', options: [
        { t: 'Never', v: 1 },
        { t: 'Rarely (1 time)', v: 2 },
        { t: 'Sometimes (2 times)', v: 3 },
        { t: 'Often (3–4 times)', v: 4 },
        { t: 'Very often (5 or more times)', v: 5 }
      ]},
      { text: 'Have you ever told someone that you were going to commit suicide, or that you might do it?', options: [
        { t: 'No', v: 1 },
        { t: 'Yes, at one time, but did not really want to die', v: 2 },
        { t: 'Yes, at one time, and really wanted to die', v: 3 },
        { t: 'Yes, more than once, and really wanted to do it', v: 3 }
      ]},
      // Published SBQ-R item 4 range is 0–6 (matches server validation).
      { text: 'How likely is it that you will attempt suicide someday?', options: [
        { t: 'Never', v: 0 },
        { t: 'No chance at all', v: 1 },
        { t: 'Rather unlikely', v: 2 },
        { t: 'Unlikely', v: 3 },
        { t: 'Likely', v: 4 },
        { t: 'Rather likely', v: 5 },
        { t: 'Very likely', v: 6 }
      ]}
    ],
    CSSRS: [
      std('Have you wished you were dead or wished you could go to sleep and not wake up?', A_YN),
      std('Have you actually had any thoughts of killing yourself?', A_YN),
      std('Have you been thinking about how you might do this?', A_YN),
      std('Have you had these thoughts and had some intention of acting on them?', A_YN),
      std('Have you started to work out or worked out the details of how to kill yourself? Do you intend to carry out this plan?', A_YN),
      std('Have you done anything, started to do anything, or prepared to do anything to end your life?', A_YN)
    ]
  };

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
    var v = parseInt($('#caseIdInput').val(), 10);
    return v > 0 ? v : 0;
  }

  var toolsByCode = {};
  var currentTool = null;

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
            return b.minScore + '–' + b.maxScore + ' ' + b.bandName;
          }).join(' · ');
          var hasQuestions = !!QUESTIONS[code];
          $grid.append(
            '<div class="card tool-card"><div class="card-body">' +
            '<h3>' + esc(t.toolName || code) + '</h3>' +
            (t.description ? '<p class="hint">' + esc(t.description) + '</p>' : '') +
            '<p class="hint">' + t.itemCount + ' items · ' + t.minScore + '–' + t.maxScore + '</p>' +
            (bands ? '<p class="hint bands">' + esc(bands) + '</p>' : '') +
            (hasQuestions
              ? '<button type="button" class="btn btn-primary btn-sm" data-open-tool="' + esc(code) + '">Open Assessment</button>'
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
      CMS.toast('Please enter a Case ID on the page before submitting.', 'error');
      $('#caseIdInput').focus();
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
      CMS.toast('Enter a Case ID first.', 'error');
      $('#caseIdInput').focus();
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

  $('#loadCaseBtn').on('click', loadCaseScreenings);
  $('#caseIdInput').on('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); loadCaseScreenings(); }
  });

  /* ------------------------------------------------------------------ *
   * init
   * ------------------------------------------------------------------ */
  loadTools();
});
