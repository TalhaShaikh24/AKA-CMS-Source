/* Reports — demo-only port of the template view script — no API calls. Charts and CSV export run against demo data. */
$(function () {

  /* ------------------------------------------------------------------ *
   * Charts (Chart.js) — monthly registrations + screening mix
   * ------------------------------------------------------------------ */
  var trend = (CMS.demo && CMS.demo.trend) || {
    labels: ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
    cases: [42, 55, 48, 63, 71, 58],
    screenings: [38, 47, 52, 60, 66, 61]
  };
  var mix = {
    labels: ['PHQ-9', 'GAD-7', 'DASS-21', 'SBQ-R', 'C-SSRS'],
    values: [86, 64, 38, 16, 10],
    colors: ['#2E3D62', '#5A6B8C', '#9AA9C7', '#DCE88A', '#8A9A5B']
  };

  if (window.Chart) {
    // NOTE: Chart.js needs the raw canvas element, not a jQuery object.
    new Chart($('#repBar')[0], {
      type: 'bar',
      data: {
        labels: trend.labels,
        datasets: [
          { label: 'Cases', data: trend.cases, backgroundColor: '#2E3D62', borderRadius: 6, barPercentage: 0.55 },
          { label: 'Screenings', data: trend.screenings, backgroundColor: '#DCE88A', borderRadius: 6, barPercentage: 0.55 }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { position: 'bottom', labels: { boxWidth: 12, usePointStyle: true } } },
        scales: { y: { beginAtZero: true, ticks: { precision: 0 } }, x: { grid: { display: false } } }
      }
    });
    new Chart($('#repDonut')[0], {
      type: 'doughnut',
      data: {
        labels: mix.labels,
        datasets: [{ data: mix.values, backgroundColor: mix.colors, borderWidth: 2, borderColor: '#fff' }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '62%',
        plugins: { legend: { position: 'bottom', labels: { boxWidth: 12, usePointStyle: true } } }
      }
    });
  } else {
    $('.chart-wrap').append('<p class="hint">Chart library could not be loaded.</p>');
  }

  /* ------------------------------------------------------------------ *
   * Filters
   * ------------------------------------------------------------------ */
  /* ------------------------------------------------------------------ *
   * Collapsible filter panel (funnel icon button)
   * ------------------------------------------------------------------ */
  function updateFilterBadge(){
    var n = 0;
    if ($('#repRange').val()) n++;
    if ($('#fRegion').val()) n++;
    if ($('#fProgram').val()) n++;
    $('#filterCount').text(n).prop('hidden', n === 0);
    $('#filterToggle').toggleClass('has-active', n > 0);
  }
  function setFilterPanel(open){
    var $p = $('#repFilterPanel');
    $('#filterToggle').attr('aria-expanded', open ? 'true' : 'false');
    if (open){
      $p.prop('hidden', false).stop(true, true).hide().slideDown(220, function(){ $p.addClass('open'); });
    } else {
      $p.stop(true, true).slideUp(220, function(){ $p.prop('hidden', true).removeClass('open'); });
    }
  }
  $('#filterToggle').on('click', function(){
    setFilterPanel($('#repFilterPanel').prop('hidden') || !$('#repFilterPanel').is(':visible'));
  });
  $('#repApplyFilters').on('click', function(){ setFilterPanel(false); });
  $('#repClearFilters').on('click', function(){
    $('#repRange').val('').trigger('change');
    $('#fRegion').val('').trigger('change');
    $('#fProgram').val('');
    updateFilterBadge();
  });

  $('#fRegion').on('change', function () {
    var r = $(this).val();
    $('#sumTable tbody tr').each(function () {
      $(this).toggle(!r || $(this).data('region') === r);
    });
    CMS.toast(r ? 'Showing ' + r : 'Showing all regions', 'info');
    updateFilterBadge();
  });
  $('#fProgram').on('change', function () {
    CMS.toast('Program filter: ' + $(this).find('option:selected').text(), 'info');
    updateFilterBadge();
  });
  $('#repRange').on('change', function () {
    if ($(this).val()) CMS.toast('Report period updated', 'info');
    updateFilterBadge();
  });

  /* ------------------------------------------------------------------ *
   * Export CSV
   * ------------------------------------------------------------------ */
  $('#exportBtn').on('click', function () {
    var rows = [['Region', 'New', 'Active', 'High Risk', 'Follow-ups Due']];
    $('#sumTable tbody tr:visible').each(function () {
      var cells = [];
      $(this).find('td').each(function () { cells.push($(this).text().trim().replace(/\s+/g, ' ')); });
      rows.push(cells);
    });
    var csv = rows.map(function (r) {
      return r.map(function (c) { return '"' + String(c).replace(/"/g, '""') + '"'; }).join(',');
    }).join('\n');
    var blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'cms-case-summary.csv';
    document.body.appendChild(a);
    a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 100);
    CMS.toast('Case summary exported as CSV', 'success');
  });

  /* ------------------------------------------------------------------ *
   * Print
   * ------------------------------------------------------------------ */
  $('#printBtn').on('click', function () { window.print(); });
});
