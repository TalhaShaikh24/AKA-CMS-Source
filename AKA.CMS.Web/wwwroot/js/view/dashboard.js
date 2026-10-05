/* Dashboard — demo-only port of the template view script — no API calls. Charts, tables and export render from CMS.demo data. */
$(function () {

  // ---- Header date ----
  $('#todayDate').text(CMS.todayStr());

  // ---- Trend line chart: cases vs screenings ----
  var trend = CMS.demo.trend || { labels: [], cases: [], screenings: [] };
  var trendEl = $('#trendChart')[0];
  if (trendEl && window.Chart) {
    new Chart(trendEl, {
      type: 'line',
      data: {
        labels: trend.labels,
        datasets: [
          {
            label: 'Cases',
            data: trend.cases,
            borderColor: '#2E3D62',
            backgroundColor: 'rgba(46,61,98,0.08)',
            borderWidth: 2.5,
            tension: 0.4,
            fill: true,
            pointBackgroundColor: '#2E3D62',
            pointRadius: 4
          },
          {
            label: 'Screenings',
            data: trend.screenings,
            borderColor: '#A8BE3A',
            backgroundColor: 'rgba(220,232,138,0.25)',
            borderWidth: 2.5,
            tension: 0.4,
            fill: true,
            pointBackgroundColor: '#A8BE3A',
            pointRadius: 4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { position: 'bottom', labels: { boxWidth: 12, usePointStyle: true } } },
        scales: { y: { beginAtZero: true, grid: { color: '#E2E8F0' } }, x: { grid: { display: false } } }
      }
    });
  }

  // ---- Risk distribution doughnut ----
  var riskDist = CMS.demo.riskDist || { labels: [], data: [], colors: [] };
  var riskEl = $('#riskChart')[0];
  if (riskEl && window.Chart) {
    new Chart(riskEl, {
      type: 'doughnut',
      data: {
        labels: riskDist.labels,
        datasets: [{ data: riskDist.data, backgroundColor: riskDist.colors, borderWidth: 3, borderColor: '#fff' }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '62%',
        plugins: { legend: { position: 'bottom', labels: { boxWidth: 12, usePointStyle: true } } }
      }
    });
  }

  // ---- Recent cases table (6) ----
  var $tbody = $('#recentCasesTable tbody');
  var cases = (CMS.demo.cases || []).slice(0, 6);
  $.each(cases, function (i, c) {
    var $tr = $('<tr class="rowlink"></tr>').attr('data-id', c.id);
    $tr.append($('<td class="pid"></td>').text(c.id));
    $tr.append($('<td></td>').html('<div class="cell-main"></div><div class="cell-sub"></div>')
      .find('.cell-main').text(c.name).end()
      .find('.cell-sub').text(c.age + ' / ' + c.gender));
    $tr.append($('<td></td>').text(c.location));
    $tr.append($('<td></td>').html(CMS.riskBadge(c.risk)));
    $tr.append($('<td></td>').html(CMS.statusPill(c.status)));
    $tbody.append($tr);
  });
  $tbody.on('click', 'tr.rowlink', function () {
    location.href = '/Cases/Details?id=' + encodeURIComponent($(this).data('id'));
  });

  // ---- Upcoming appointments (4) ----
  var appts = (CMS.demo.appointments || [
    { patient: 'Sadia Noor', caseId: 'CMS-1042', time: 'Today · 10:30 AM', type: 'Follow-up visit' },
    { patient: 'Imran Baig', caseId: 'CMS-1037', time: 'Today · 12:00 PM', type: 'Initial screening' },
    { patient: 'Naseem Akhtar', caseId: 'CMS-1051', time: 'Tomorrow · 09:15 AM', type: 'Therapy session' },
    { patient: 'Fida Hussain', caseId: 'CMS-1029', time: 'Tomorrow · 11:45 AM', type: 'Medication review' }
  ]).slice(0, 4);
  var $apptList = $('#apptList');
  $.each(appts, function (i, a) {
    var $row = $('<div class="appt"></div>');
    $row.append($('<span class="avatar sm"></span>').text(CMS.initials(a.patient)));
    $row.append($('<div class="appt-info"></div>').html(
      '<div class="cell-main"></div><div class="cell-sub"></div>'
    ).find('.cell-main').text(a.patient).end().find('.cell-sub').text(a.time));
    $row.append($('<span class="appt-type"></span>').text(a.type));
    $apptList.append($row);
  });

  // ---- Follow-ups due ----
  var $fuList = $('#followupList');
  var followups = CMS.demo.followups || [];
  if (!followups.length) {
    $fuList.append('<div class="empty">No follow-ups due.</div>');
  }
  $.each(followups, function (i, f) {
    $fuList.append(
      '<a class="fu-row" href="/Cases/Details?id=' + encodeURIComponent(f.caseId) + '">' +
      '<span class="avatar sm">' + CMS.initials(f.patient) + '</span>' +
      '<div class="fu-info"><div class="cell-main">' + $('<div>').text(f.patient).html() + '</div>' +
      '<div class="cell-sub">Due ' + $('<div>').text(f.due).html() + ' · ' + $('<div>').text(f.type).html() + '</div></div>' +
      '<span class="pid">' + $('<div>').text(f.caseId).html() + '</span></a>'
    );
  });

  // ---- Export ----
  $('#exportBtn').on('click', function () {
    CMS.toast('Demo preview — connect the reporting API to export live data.', 'info');
  });
});
