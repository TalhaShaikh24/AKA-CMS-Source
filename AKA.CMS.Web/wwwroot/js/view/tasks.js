/* ==========================================================================
   Tasks & Assignments — matches the CMO design: priority/due filters +
   task queue table. Loaded through cmsAjax DIRECTLY from the Web API.
   ========================================================================== */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();

  var allTasks = [];

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function fmtDate(d) {
    if (!d) return '—';
    var dt = new Date(d.length <= 10 ? d + 'T00:00:00' : d);
    return dt.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
  }
  function prioBadge(p) {
    var v = String(p || '').toLowerCase();
    var cls = v === 'high' || v === 'urgent' ? 'high' : v === 'medium' ? 'medium' : v === 'low' ? 'low' : 'gray';
    return '<span class="badge ' + cls + '">' + esc(p || '—') + '</span>';
  }
  function dueText(t) {
    if (!t.dueDate) return '—';
    if (t.status === 'Completed' || t.status === 'Cancelled') return fmtDate(t.dueDate);
    var today = new Date(); today.setHours(0, 0, 0, 0);
    var due = new Date(t.dueDate + 'T00:00:00');
    var diff = Math.round((due - today) / 86400000);
    if (diff < 0) return 'Overdue';
    if (diff === 0) return 'Due today';
    return 'Due in ' + diff + ' day' + (diff === 1 ? '' : 's');
  }
  function dueKey(t) {
    if (!t.dueDate || t.status === 'Completed' || t.status === 'Cancelled') return '';
    var today = new Date(); today.setHours(0, 0, 0, 0);
    var due = new Date(t.dueDate + 'T00:00:00');
    var diff = Math.round((due - today) / 86400000);
    if (diff < 0) return 'overdue';
    if (diff === 0) return 'today';
    return '';
  }

  function load() {
    cmsAjax({
      url: '/api/tasks', method: 'GET',
      fallbackMsg: 'Could not load tasks.',
      success: function (res) { allTasks = res || []; render(); },
      error: function () { $('#taskRows').html('<tr><td colspan="5"><div class="empty">Could not load tasks.</div></td></tr>'); }
    });
  }

  function render() {
    var pri = $('#taskPriority').val();
    var due = $('#taskDue').val();
    var rows = allTasks.filter(function (t) {
      if (pri && String(t.priority || '').toLowerCase() !== pri.toLowerCase()) return false;
      if (due && dueKey(t) !== due) return false;
      return true;
    });
    var html = rows.map(function (t) {
      return '<tr>' +
        '<td><b>' + esc(t.title) + '</b></td>' +
        '<td>' + esc((t.patientName || '') + (t.caseNumber ? ' | ' + t.caseNumber : '')) + '</td>' +
        '<td>' + prioBadge(t.priority) + '</td>' +
        '<td>' + esc(dueText(t)) + '</td>' +
        '<td><button class="btn small secondary" data-open="' + t.taskId + '">Open</button></td>' +
        '</tr>';
    }).join('');
    $('#taskRows').html(html || '<tr><td colspan="5"><div class="empty">No tasks found.</div></td></tr>');
  }

  $('#taskPriority, #taskDue').on('change', render);
  $(document).on('click', '[data-open]', function () {
    CMS.toast('Task #' + $(this).data('open'), 'info');
  });

  load();
});
