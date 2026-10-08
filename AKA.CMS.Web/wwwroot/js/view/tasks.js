/* Tasks list — tabs All / Due Today / Overdue, cards with
   status actions. Loaded through cmsAjax DIRECTLY from the Web API. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();

  var currentTab = 'All';
  var counts = { All: 0, DueToday: 0, Overdue: 0 };

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

  function dueInfo(t) {
    if (t.status === 'Completed' || t.status === 'Cancelled') return { cls: '', text: fmtDate(t.dueDate) };
    var today = new Date(); today.setHours(0, 0, 0, 0);
    var due = new Date(t.dueDate + 'T00:00:00');
    var diff = Math.round((due - today) / 86400000);
    if (diff < 0) return { cls: 'due-over', text: 'Overdue · ' + fmtDate(t.dueDate) };
    if (diff === 0) return { cls: 'due-today', text: 'Due today · ' + fmtDate(t.dueDate) };
    return { cls: 'due-ok', text: 'Due in ' + diff + ' day' + (diff === 1 ? '' : 's') + ' · ' + fmtDate(t.dueDate) };
  }

  function fmtDate(d) {
    if (!d) return '—';
    var dt = new Date(d.length <= 10 ? d + 'T00:00:00' : d);
    return dt.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
  }

  function statusPill(s) {
    var cls = { Pending: 'pill-pending', InProgress: 'pill-inprogress', Completed: 'pill-completed', Cancelled: 'pill-cancelled' }[s] || 'pill-pending';
    return '<span class="pill ' + cls + '">' + esc(s) + '</span>';
  }

  function load() {
    $('#taskList').html('<p class="hint">Loading&hellip;</p>');
    cmsAjax({
      url: '/api/tasks', method: 'GET',
      data: { tab: currentTab },
      fallbackMsg: 'Could not load tasks.',
      success: function (res) { render(res || []); }
    });
    // tab counts (cheap: three parallel calls)
    ['All', 'DueToday', 'Overdue'].forEach(function (tab) {
      cmsAjax({
        url: '/api/tasks', method: 'GET', data: { tab: tab },
        fallbackMsg: '', quiet: true,
        success: function (res) {
          counts[tab] = (res || []).length;
          $('#cnt' + tab).text('(' + counts[tab] + ')');
        }
      });
    });
  }

  function render(tasks) {
    if (!tasks.length) {
      $('#taskList').html('<p class="hint">No tasks in this tab.</p>');
      return;
    }
    var html = '';
    tasks.forEach(function (t) {
      var d = dueInfo(t);
      html += '<div class="task-card" data-id="' + t.taskId + '" data-rv="' + esc(t.rowVersion || '') + '">' +
        '<div><div class="t-title">' + esc(t.title) + '</div>' +
        '<div class="t-meta">' + esc(t.patientName || 'Unknown') + ' | ' + esc(t.caseNumber || ('#' + t.caseId)) +
        ' · ' + esc(t.taskType || 'General') +
        (t.assignedUserName ? ' · ' + esc(t.assignedUserName) : (t.assignedRoleName ? ' · ' + esc(t.assignedRoleName) : '')) + '</div>' +
        '<div class="t-due ' + d.cls + '">' + esc(d.text) + '</div>' +
        '<div style="margin-top:6px"><span class="pill pill-' + t.priority.toLowerCase() + '">' + esc(t.priority) + '</span> ' + statusPill(t.status) + '</div></div>' +
        '<div class="task-actions" data-permission="Tasks:Write">' +
        (t.status === 'Pending' ? '<button class="btn btn-ghost btn-sm" data-start>Start</button>' : '') +
        (t.status !== 'Completed' && t.status !== 'Cancelled' ? '<button class="btn btn-ghost btn-sm" data-done>Complete</button>' : '') +
        '</div></div>';
    });
    $('#taskList').html(html);
    if (window.CMS && typeof CMS.applyPermissions === 'function') CMS.applyPermissions(document);
  }

  function setStatus(card, status) {
    var id = +card.data('id');
    var rv = card.data('rv');
    cmsAjax({
      url: '/api/tasks/' + id + '/status', method: 'PATCH',
      data: JSON.stringify({ status: status, rowVersion: rv }),
      fallbackMsg: 'Could not update the task.',
      success: function () { CMS.toast('Task updated.', 'success'); load(); }
    });
  }

  $('#taskList').on('click', '[data-start]', function () { setStatus($(this).closest('.task-card'), 'InProgress'); });
  $('#taskList').on('click', '[data-done]', function () { setStatus($(this).closest('.task-card'), 'Completed'); });

  $('.tabbar .tab').on('click', function () {
    $('.tabbar .tab').removeClass('active');
    $(this).addClass('active');
    currentTab = $(this).data('tab');
    load();
  });

  load();
});
