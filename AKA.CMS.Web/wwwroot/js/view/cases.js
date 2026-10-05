/* Cases — demo-only port of the template view script — no API calls. Filters, search and pagination run against CMS.demo data. */
$(function () {

  var state = { q: '', filters: {}, page: 1, perPage: 8 };
  var $tbody = $('#casesTable tbody');
  var $empty = $('#casesEmpty');

  // ---- Filters ----
  $('#caseFilters').cmsFilters({
    filters: [
      { key: 'status', label: 'Status', type: 'select', options: ['New', 'Active', 'Follow-up Due', 'LTFU'], placeholder: 'All statuses' },
      { key: 'risk', label: 'Risk', type: 'select', options: ['low', 'moderate', 'high', 'crisis'], placeholder: 'All risks' },
      { key: 'region', label: 'Region', type: 'select', options: ['Skardu', 'Gojal', 'Hunza', 'Ghizer', 'Booni'], placeholder: 'All regions' },
      { key: 'assignee', label: 'Assignee', type: 'select', options: ['Ayesha Khan', 'Dr. Ahmed Khan', 'Bilal Ahmed'], placeholder: 'All assignees' },
      { key: 'registered', label: 'Registered', type: 'daterange', placeholder: 'Any date' }
    ],
    onChange: function (v) {
      state.filters = v || {};
      state.page = 1;
      render();
      updateFilterBadge();
    }
  });

  // ---- Collapsible filter panel (funnel icon button) ----
  function updateFilterBadge(){
    var st = $('#caseFilters').data('cmsfilters');
    var vals = st ? st.getValues() : {};
    var n = 0;
    $.each(vals, function(k, v){ if (v !== '' && v != null) n++; });
    $('#filterCount').text(n).prop('hidden', n === 0);
    $('#filterToggle').toggleClass('has-active', n > 0);
  }
  function setFilterPanel(open){
    var $p = $('#caseFilterPanel');
    $('#filterToggle').attr('aria-expanded', open ? 'true' : 'false');
    if (open){
      $p.prop('hidden', false).stop(true, true).hide().slideDown(220, function(){ $p.addClass('open'); });
    } else {
      $p.stop(true, true).slideUp(220, function(){ $p.prop('hidden', true).removeClass('open'); });
    }
  }
  $('#filterToggle').on('click', function(){
    setFilterPanel($('#caseFilterPanel').prop('hidden') || !$('#caseFilterPanel').is(':visible'));
  });
  $('#caseApplyFilters').on('click', function(){ setFilterPanel(false); });
  $('#caseClearFilters').on('click', function(){
    var st = $('#caseFilters').data('cmsfilters');
    if (st) st.reset();
    updateFilterBadge();
  });

  // ---- Search ----
  var searchTimer;
  $('#caseSearch').on('input', function () {
    var q = $(this).val();
    clearTimeout(searchTimer);
    searchTimer = setTimeout(function () {
      state.q = q.trim().toLowerCase();
      state.page = 1;
      render();
    }, 200);
  });

  // ---- Filtering ----
  function filteredCases() {
    var all = CMS.demo.cases || [];
    return all.filter(function (c) {
      if (state.q && (c.name + ' ' + c.id).toLowerCase().indexOf(state.q) === -1) return false;
      var f = state.filters;
      if (f.status && c.status !== f.status) return false;
      if (f.risk && c.risk !== f.risk) return false;
      if (f.region && c.location !== f.region) return false;
      if (f.assignee && c.assignee !== f.assignee) return false;
      // 'registered' date range is decorative in demo mode
      return true;
    });
  }

  // ---- Render rows + pager ----
  function render() {
    var rows = filteredCases();
    var total = rows.length;
    var pages = Math.max(1, Math.ceil(total / state.perPage));
    if (state.page > pages) state.page = pages;
    var start = (state.page - 1) * state.perPage;
    var pageRows = rows.slice(start, start + state.perPage);

    $tbody.empty();
    $empty.prop('hidden', total > 0);
    $.each(pageRows, function (i, c) {
      var $tr = $('<tr class="rowlink"></tr>').attr('data-id', c.id);
      $tr.append($('<td class="td-check"></td>').html('<input type="checkbox" class="row-check" aria-label="Select case">'));
      $tr.append($('<td class="pid"></td>').text(c.id));
      $tr.append($('<td></td>').html('<div class="cell-main"></div><div class="cell-sub"></div>')
        .find('.cell-main').text(c.name).end()
        .find('.cell-sub').text(c.location));
      $tr.append($('<td></td>').text(c.age + ' / ' + c.gender));
      $tr.append($('<td></td>').text(c.location));
      $tr.append($('<td></td>').html(CMS.riskBadge(c.risk)));
      $tr.append($('<td></td>').html(CMS.statusPill(c.status)));
      $tr.append($('<td></td>').text(c.assignee));
      $tr.append($('<td class="muted"></td>').text(c.updated));
      $tbody.append($tr);
    });

    $('#caseCount').text(total + (total === 1 ? ' case' : ' cases'));

    var $pager = $('#casePager').empty();
    if (pages > 1) {
      for (var p = 1; p <= pages; p++) {
        (function (pn) {
          var $btn = $('<button type="button" class="page-btn"></button>')
            .text(pn).toggleClass('active', pn === state.page)
            .on('click', function () { state.page = pn; render(); });
          $pager.append($btn);
        })(p);
      }
    }
    $('#selectAll').prop('checked', false);
  }

  // ---- Row clicks + checkbox isolation ----
  $tbody.on('click', 'tr.rowlink', function (e) {
    if ($(e.target).closest('.td-check, .row-check').length) return;
    location.href = '/Cases/Details?id=' + encodeURIComponent($(this).data('id'));
  });
  $tbody.on('click', '.row-check', function (e) { e.stopPropagation(); });

  $('#selectAll').on('change', function () {
    $tbody.find('.row-check').prop('checked', $(this).is(':checked'));
  });

  // ---- Export CSV ----
  $('#exportCsvBtn').on('click', function () {
    var rows = filteredCases();
    var head = ['Case ID', 'Patient', 'Age', 'Gender', 'Location', 'Risk', 'Status', 'Assignee', 'Updated'];
    var esc = function (v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; };
    var lines = [head.map(esc).join(',')];
    $.each(rows, function (i, c) {
      lines.push([c.id, c.name, c.age, c.gender, c.location, c.risk, c.status, c.assignee, c.updated].map(esc).join(','));
    });
    var blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' });
    var $a = $('<a></a>').attr({ href: URL.createObjectURL(blob), download: 'cms-cases.csv' }).appendTo('body');
    $a[0].click();
    setTimeout(function () { URL.revokeObjectURL($a.attr('href')); $a.remove(); }, 500);
    CMS.toast('Exported ' + rows.length + ' case(s) to CSV.', 'success');
  });

  render();
});
