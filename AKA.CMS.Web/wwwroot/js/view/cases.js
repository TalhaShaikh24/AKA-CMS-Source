/* ==========================================================================
   CMS · My Cases — js/view/cases.js
   Matches the CMO design: search + status/risk filters, case register
   table with risk badges. API-wired (no demo data):
     GET /api/cases?search=&page=&pageSize=  → paged case list
   Row "View" → /Cases/Details?id={caseId}
   ========================================================================== */
$(function () {
  'use strict';
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();

  var PAGE_SIZE = 20;
  var state = { search: '', status: '', risk: '', page: 1, totalCount: 0, items: [] };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function riskBadge(level) {
    var v = String(level || '').toLowerCase();
    var cls = v === 'high' || v === 'critical' ? 'high'
      : v === 'medium' || v === 'moderate' ? 'medium'
      : v === 'low' ? 'low' : 'gray';
    return '<span class="badge ' + cls + '">' + esc(level || '—') + '</span>';
  }
  function statusBadge(s) {
    return '<span class="badge blue">' + esc(s || '—') + '</span>';
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
        renderStatuses();
        renderTable();
        renderPager();
      },
      error: function () { CMS.loader(false); }
    });
  }

  function renderStatuses() {
    var seen = {};
    state.items.forEach(function (c) {
      var s = c.statusName || c.status;
      if (s && !seen[s]) seen[s] = true;
    });
    var cur = $('#caseStatusFilter').val();
    var html = '<option value="">All Status</option>' + Object.keys(seen).sort().map(function (s) {
      return '<option value="' + esc(s) + '">' + esc(s) + '</option>';
    }).join('');
    $('#caseStatusFilter').html(html);
    if (cur) $('#caseStatusFilter').val(cur);
  }

  function matchFilters(c) {
    if (state.status && (c.statusName || c.status) !== state.status) return false;
    if (state.risk && String(c.priorityLevel || '').toLowerCase() !== state.risk.toLowerCase()) return false;
    return true;
  }

  function renderTable() {
    var rows = state.items.filter(matchFilters);
    var html = rows.map(function (c) {
      var ageGender = [c.memberAge != null ? c.memberAge : null, c.memberGender].filter(function (x) { return x; }).join(' / ') || '—';
      return '<tr>' +
        '<td><strong>' + esc(c.caseNumber || ('#' + c.caseId)) + '</strong></td>' +
        '<td>' + esc(c.memberName || 'Unknown patient') + '</td>' +
        '<td>' + esc(ageGender) + '</td>' +
        '<td>' + esc(c.memberVillage || '—') + '</td>' +
        '<td>' + riskBadge(c.priorityLevel) + '</td>' +
        '<td>' + statusBadge(c.statusName || c.status) + '</td>' +
        '<td><button class="btn small secondary" data-view="' + c.caseId + '">View</button></td>' +
        '</tr>';
    }).join('');
    $('#caseRows').html(html || '<tr><td colspan="7"><div class="empty">No cases found.</div></td></tr>');
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
  $('#caseStatusFilter').on('change', function () { state.status = $(this).val(); renderTable(); });
  $('#caseRiskFilter').on('change', function () { state.risk = $(this).val(); renderTable(); });

  $(document).on('click', '[data-view]', function () {
    location.href = '/Cases/Details?id=' + encodeURIComponent($(this).data('view'));
  });

  loadCases();
});
