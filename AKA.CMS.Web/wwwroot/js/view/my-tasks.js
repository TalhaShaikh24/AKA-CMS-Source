/* My Tasks — workflow instances waiting for the logged-in user's
   roles, via GET /api/workflow-instances/my-tasks. Open jumps to
   the Render page in workflow mode (?instanceId=); History shows
   the instance log (one row per move). */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  function fmtDate(v) {
    if (!v) return '—';
    var d = new Date(v);
    return isNaN(d) ? '—' : d.toLocaleDateString();
  }

  function fmtDateTime(v) {
    if (!v) return '—';
    var d = new Date(v);
    return isNaN(d) ? '—' : d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function load() {
    cmsAjax({
      url: '/api/workflow-instances/my-tasks', method: 'GET',
      fallbackMsg: 'Could not load tasks.',
      success: function (res) {
        var rows = res || [];
        $('#mtCount').text(rows.length + ' task' + (rows.length === 1 ? '' : 's'));
        $('#mtTbody').html(rows.map(function (t) {
          var overdue = t.sla_Date && new Date(t.sla_Date) < new Date();
          return '<tr>' +
            '<td><strong>' + esc(t.workflowName) + '</strong>' +
              (t.workflowCode ? '<br><span class="hint"><code>' + esc(t.workflowCode) + '</code></span>' : '') + '</td>' +
            '<td>' + esc(t.formTitle) + '<br><span class="hint">Entry #' + t.submissionId + '</span></td>' +
            '<td>' + esc(t.currentStepTitle || t.currentStepCode) + '</td>' +
            '<td>' + esc(t.currentRoleName || '—') + '</td>' +
            '<td>' + (overdue ? '<span style="color:#b3261e"><strong>' + fmtDate(t.sla_Date) + '</strong></span>' : fmtDate(t.sla_Date)) + '</td>' +
            '<td class="row-actions" style="white-space:nowrap">' +
              '<a class="btn btn-primary btn-sm" href="/DynamicForms/Render/' + t.formId + '?instanceId=' + t.workflowInstanceId + '">Open</a> ' +
              '<button class="btn btn-ghost btn-sm" data-log="' + t.workflowInstanceId + '" data-title="' + esc(t.workflowName) + ' — ' + esc(t.currentStepTitle || t.currentStepCode) + '" type="button">History</button>' +
            '</td></tr>';
        }).join('') || '<tr><td colspan="6" class="hint">No tasks waiting for you.</td></tr>');
      }
    });
  }

  $(document).on('click', '[data-log]', function () {
    var id = $(this).data('log');
    $('#mtLogTitle').text('History — ' + $(this).data('title'));
    $('#mtLogBody').html('<div class="hint">Loading&hellip;</div>');
    $('#mtLogModal').addClass('open');
    cmsAjax({
      url: '/api/workflow-instances/' + id + '/log', method: 'GET',
      fallbackMsg: 'Could not load history.',
      success: function (res) {
        var rows = res || [];
        $('#mtLogBody').html(rows.length ? rows.map(function (l) {
          return '<div style="padding:8px 0;border-bottom:1px solid var(--border)">' +
            '<strong>' + esc(l.status || l.currentStepTitle || l.currentStepCode) + '</strong> — ' +
            esc(l.currentStepTitle || l.currentStepCode) +
            ' <span class="hint">(' + esc(l.currentRoleName || 'no role') + ')</span><br>' +
            '<span class="hint">' + fmtDateTime(l.logDate) +
            (l.comments ? ' · ' + esc(l.comments) : '') + '</span></div>';
        }).join('') : '<div class="hint">No history yet.</div>');
      }
    });
  });

  load();
});
