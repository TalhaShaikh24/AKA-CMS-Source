/* ==========================================================================
   Follow-ups — matches the CMO design: filter + follow-up queue table.
   API-wired (no demo data):
     GET  /api/followups/due       → due queue
     POST /api/followups/schedule  → schedule a follow-up
   ========================================================================== */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);
  CMS.initValidation(document);

  var allRows = [];

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function fmtDate(d) {
    if (!d) return '—';
    try { return new Date(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }); }
    catch (e) { return '—'; }
  }
  function statusOf(r) {
    // Due date = last contact + frequency
    var due = new Date(r.lastContactDate);
    due.setDate(due.getDate() + (r.frequencyDays || 30));
    var today = new Date(); today.setHours(0, 0, 0, 0);
    var dd = new Date(due); dd.setHours(0, 0, 0, 0);
    if (dd < today) return 'Overdue';
    if (dd.getTime() === today.getTime()) return 'Due Today';
    return 'Upcoming';
  }
  function statusBadge(s) {
    var cls = /over|miss/i.test(s) ? 'high' : /today/i.test(s) ? 'medium' : 'blue';
    return '<span class="badge ' + cls + '">' + esc(s) + '</span>';
  }

  function load() {
    cmsAjax({
      url: '/api/followups/due', method: 'GET',
      fallbackMsg: 'Could not load follow-ups.',
      success: function (res) {
        allRows = (res || []).map(function (r) {
          var due = new Date(r.lastContactDate);
          due.setDate(due.getDate() + (r.frequencyDays || 30));
          r._dueDate = due;
          r._status = statusOf(r);
          return r;
        });
        render();
      },
      error: function () { $('#followRows').html('<tr><td colspan="5"><div class="empty">Could not load follow-ups.</div></td></tr>'); }
    });
  }

  function render() {
    var f = $('#followFilter').val();
    var rows = allRows.filter(function (r) { return !f || r._status === f; });
    var html = rows.map(function (r) {
      return '<tr>' +
        '<td><b>' + esc(r.caseNumber) + '</b><br><small>' + esc(r.caseStatus || '') + '</small></td>' +
        '<td>' + esc(fmtDate(r._dueDate)) + '</td>' +
        '<td>' + esc(r.priorityLevel || '—') + '</td>' +
        '<td>' + statusBadge(r._status) + '</td>' +
        '<td><button class="btn small secondary" data-case="' + r.caseId + '">Open Case</button></td>' +
        '</tr>';
    }).join('');
    $('#followRows').html(html || '<tr><td colspan="5"><div class="empty">No follow-ups found.</div></td></tr>');
  }

  $('#followFilter').on('change', render);
  $(document).on('click', '[data-case]', function () {
    location.href = '/Cases/Details?id=' + $(this).data('case');
  });

  /* ---------- schedule modal ---------- */
  $('#bookBtn').on('click', function () {
    cmsAjax({ url: '/api/cases', method: 'GET', data: { page: 1, pageSize: 100 },
      success: function (res) {
        var html = '<option value="" selected disabled>Select case</option>';
        ((res && res.items) || []).forEach(function (c) {
          html += '<option value="' + c.caseId + '">' + esc(c.caseNumber || ('#' + c.caseId)) + '</option>';
        });
        $('#bCase').html(html);
      }
    });
    $('#bookModal').addClass('open');
  });

  $('#bookForm').cmsValidate({
    onValid: function () {
      cmsAjax({
        url: '/api/followups/schedule', method: 'POST', json: true,
        data: {
          caseId: parseInt($('#bCase').val(), 10),
          scheduledDate: $('#bDate').val(),
          followUpType: $('#bType').val(),
          notes: $.trim($('#bNotes').val()) || null
        },
        fallbackMsg: 'Could not schedule the follow-up.',
        success: function () {
          CMS.toast('Follow-up scheduled.', 'success');
          $('#bookModal').removeClass('open');
          load();
        }
      });
    }
  });

  load();
});
