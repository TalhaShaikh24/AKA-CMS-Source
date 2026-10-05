/* ==========================================================================
   CMS · Cases — js/view/cases.js
   API-wired (no demo data):
     GET /api/cases?search=&page=&pageSize=  → paged case list
   Row click → /Cases/Details?id={caseId}
   ========================================================================== */
$(function () {
  'use strict';

  var PAGE_SIZE = 20;
  var state = { search: '', page: 1, totalCount: 0, items: [] };

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
  function priorityBadge(p) {
    var v = String(p || '').toLowerCase();
    var cls = v === 'high' ? 'badge-high' : v === 'low' ? 'badge-low' : 'badge-moderate';
    return '<span class="badge ' + cls + '">' + esc(p || '—') + '</span>';
  }

  function loadCases() {
    CMS.loader(true);
    cmsAjax({
      url: '/api/cases',
      method: 'GET',
      data: { search: state.search, page: state.page, pageSize: PAGE_SIZE },
      fallbackMsg: 'Could not load cases.',
      success: function (res) {
        CMS.loader(false);
        state.items = res.items || [];
        state.totalCount = res.totalCount || 0;
        renderTable();
        renderPager();
      },
      error: function () { CMS.loader(false); }
    });
  }

  function renderTable() {
    var $tb = $('#casesTable tbody').empty();
    $('#casesEmpty').prop('hidden', state.items.length > 0);
    $('#caseCount').text(state.totalCount + ' case' + (state.totalCount === 1 ? '' : 's'));
    state.items.forEach(function (c) {
      $tb.append(
        '<tr class="rowlink" data-id="' + c.caseId + '">' +
        '<td><div class="cell-main">' + esc(c.caseNumber || ('#' + c.caseId)) + '</div></td>' +
        '<td><div class="cell-main">' + esc(c.memberName || 'Unknown patient') + '</div>' +
        (c.memberMrNo ? '<div class="cell-sub">' + esc(c.memberMrNo) + '</div>' : '') + '</td>' +
        '<td><span class="pill">' + esc(c.statusName || c.status) + '</span></td>' +
        '<td>' + priorityBadge(c.priorityLevel) + '</td>' +
        '<td>' + esc(fmtDate(c.createdAt)) + '</td>' +
        '</tr>'
      );
    });
  }

  function renderPager() {
    var pages = Math.max(1, Math.ceil(state.totalCount / PAGE_SIZE));
    var $p = $('#casePager').empty();
    if (state.totalCount <= PAGE_SIZE) return;
    $p.append(
      '<button class="btn btn-ghost btn-sm" id="pgPrev" type="button" ' + (state.page <= 1 ? 'disabled' : '') + '>‹ Prev</button>' +
      '<span class="hint">Page ' + state.page + ' of ' + pages + '</span>' +
      '<button class="btn btn-ghost btn-sm" id="pgNext" type="button" ' + (state.page >= pages ? 'disabled' : '') + '>Next ›</button>'
    );
  }

  $('#casePager').on('click', '#pgPrev', function () {
    if (state.page > 1) { state.page--; loadCases(); }
  });
  $('#casePager').on('click', '#pgNext', function () {
    if (state.page * PAGE_SIZE < state.totalCount) { state.page++; loadCases(); }
  });

  var searchTimer = null;
  $('#caseSearch').on('input', function () {
    clearTimeout(searchTimer);
    var v = $(this).val();
    searchTimer = setTimeout(function () {
      state.search = $.trim(v);
      state.page = 1;
      loadCases();
    }, 350);
  });

  $('#casesTable').on('click', 'tr.rowlink', function () {
    location.href = '/Cases/Details?id=' + encodeURIComponent($(this).data('id'));
  });

  $('#exportCsvBtn').on('click', function () {
    if (!state.items.length) { CMS.toast('Nothing to export.', 'info'); return; }
    var rows = [['Case ID', 'Case Number', 'Patient', 'MR No', 'Status', 'Priority', 'Created']];
    state.items.forEach(function (c) {
      rows.push([c.caseId, c.caseNumber || '', c.memberName || '', c.memberMrNo || '',
        c.statusName || c.status, c.priorityLevel || '', c.createdAt || '']);
    });
    var csv = rows.map(function (r) {
      return r.map(function (v) { return '"' + String(v).replace(/"/g, '""') + '"'; }).join(',');
    }).join('\r\n');
    var blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'cases-page-' + state.page + '.csv';
    document.body.appendChild(a);
    a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500);
  });

  loadCases();
});
