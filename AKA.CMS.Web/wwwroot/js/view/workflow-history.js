/* Workflow history — one shared flow chart + log, used by My Tasks,
   My Requests and the Render page (continue mode). The chart is
   built from the instance's own data, never hardcoded: the workflow's
   steps in order, the instance's current step, and the log of moves.
   A step is Done when the log shows the instance reached it, Current
   when the instance is there now, Upcoming otherwise. An end step
   reached is green (Complete) — red when its code or title says
   Reject. */
window.WorkflowHistory = (function () {
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  function fmtDateTime(v) {
    if (!v) return '—';
    var d = new Date(v);
    return isNaN(d) ? '—' : d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function whoOf(step) {
    return step.responsibleWorkflowRoleName || step.responsibleRoleName || 'No role';
  }

  var nodeStyles = {
    done: 'background:#e6f4ea;border:1.5px solid #34a853;color:#137333',
    current: 'background:#e8f0fe;border:1.5px solid #1a73e8;color:#174ea6',
    upcoming: 'background:#f8f9fa;border:1.5px solid #dadce0;color:#5f6368',
    endDone: 'background:#34a853;border:1.5px solid #34a853;color:#fff',
    endReject: 'background:#d93025;border:1.5px solid #d93025;color:#fff'
  };

  /* Steps + instance + log -> the chart HTML. Pure function, so the
     same chart renders for any workflow the user can see. */
  function chartHtml(steps, instance, log) {
    var visited = {};
    (log || []).forEach(function (l) { if (l.currentStepCode) visited[l.currentStepCode] = true; });
    var current = instance ? instance.currentStepCode : null;
    var nodes = (steps || []).map(function (s, i) {
      var isCurrent = s.stepCode === current;
      var isDone = !isCurrent && !!visited[s.stepCode];
      var isReject = /reject/i.test(s.stepCode || '') || /reject/i.test(s.stepTitle || '');
      var cls, label;
      if (isCurrent && s.isEnd) { cls = isReject ? 'endReject' : 'endDone'; label = isReject ? 'Rejected' : 'Done'; }
      else if (isCurrent) { cls = 'current'; label = 'Now here'; }
      else if (isDone) { cls = 'done'; label = 'Done'; }
      else { cls = 'upcoming'; label = s.isEnd ? 'End' : 'Upcoming'; }
      var node = '<div style="' + nodeStyles[cls] + ';border-radius:10px;padding:8px 10px;min-width:110px;max-width:180px;flex:1 1 120px">' +
        '<div style="font-size:11px;opacity:.8">' + (i + 1) + ' · ' + esc(label) + '</div>' +
        '<div style="font-weight:700;font-size:13px">' + esc(s.stepTitle || s.stepCode) + '</div>' +
        '<div style="font-size:12px;opacity:.85">' + esc(whoOf(s)) + '</div>' +
        '</div>';
      return i === 0 ? node : '<div style="align-self:center;color:#9aa0a6;font-size:18px">&rarr;</div>' + node;
    }).join('');
    if (!nodes) return '<div class="hint">No steps in this workflow.</div>';
    return '<div style="display:flex;flex-wrap:wrap;gap:6px;align-items:stretch;margin-bottom:6px">' + nodes + '</div>' +
      '<div class="hint" style="margin-bottom:10px">' +
      '<span style="color:#137333">&#9679;</span> Done &nbsp; ' +
      '<span style="color:#174ea6">&#9679;</span> Now here &nbsp; ' +
      '<span style="color:#5f6368">&#9679;</span> Upcoming &nbsp; ' +
      '<span style="color:#d93025">&#9679;</span> Rejected</div>';
  }

  function logHtml(rows) {
    if (!rows || !rows.length) return '<div class="hint">No history yet.</div>';
    return rows.map(function (l) {
      return '<div style="padding:8px 0;border-bottom:1px solid var(--border)">' +
        '<strong>' + esc(l.status || l.currentStepTitle || l.currentStepCode) + '</strong> — ' +
        esc(l.currentStepTitle || l.currentStepCode) +
        ' <span class="hint">(' + esc(l.currentWorkflowRoleName || l.currentRoleName || 'no role') + ')</span><br>' +
        '<span class="hint">' + fmtDateTime(l.logDate) +
        (l.comments ? ' · ' + esc(l.comments) : '') + '</span></div>';
    }).join('');
  }

  /* Open the history modal for one instance: chart on top, log
     below. opts: { modal, titleEl, bodyEl, instanceId, title }. */
  function open(opts) {
    $(opts.titleEl).text(opts.title);
    $(opts.bodyEl).html('<div class="hint">Loading&hellip;</div>');
    $(opts.modal).addClass('open');
    cmsAjax({
      url: '/api/workflow-instances/' + opts.instanceId, method: 'GET',
      fallbackMsg: 'Could not load request.',
      success: function (inst) {
        cmsAjax({
          url: '/api/workflows/' + inst.workflowId + '/steps', method: 'GET',
          fallbackMsg: 'Could not load workflow steps.',
          success: function (steps) {
            cmsAjax({
              url: '/api/workflow-instances/' + opts.instanceId + '/log', method: 'GET',
              fallbackMsg: 'Could not load history.',
              success: function (log) {
                $(opts.bodyEl).html(chartHtml(steps, inst, log || []) + logHtml(log || []));
              }
            });
          }
        });
      }
    });
  }

  return { open: open, chartHtml: chartHtml, logHtml: logHtml };
})();
