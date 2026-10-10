/* Referrals queue — loaded through the global cmsAjax helper
   DIRECTLY from the Web API. Razor never touches the backend. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  $('[data-go]').on('click', function () { location.href = $(this).data('go'); });

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

  function badge(text, cls) { return '<span class="badge ' + cls + '">' + esc(text) + '</span>'; }
  function prioBadge(s) {
    s = String(s || '');
    if (/emergency|high|urgent/i.test(s)) return badge(s, 'high');
    return badge(s || '—', 'blue');
  }
  function statusBadge(s) {
    s = String(s || '');
    if (/accept/i.test(s)) return badge(s, 'low');
    if (/reject/i.test(s)) return badge(s, 'high');
    return badge(s || '—', 'blue');
  }

  cmsAjax({
    url: '/api/referrals?top=100', method: 'GET',
    fallbackMsg: 'Could not load referrals.',
    success: function (res) {
      var rows = res || [];
      var html = rows.map(function (r) {
        return '<tr><td><strong>' + esc(r.referralNumber) + '</strong><br><small>' + esc(r.caseNumber || ('Case #' + r.caseId)) + '</small></td>' +
          '<td>' + esc(r.referredTo) + '</td>' +
          '<td>' + esc(r.createdByUsername || '—') + '</td>' +
          '<td>' + statusBadge(r.status) + '</td>' +
          '<td><button class="btn small secondary" data-details="' + r.referralId + '">Details</button></td></tr>';
      }).join('');
      $('#refRows').html(html || '<tr><td colspan="5"><div class="empty">No referrals found.</div></td></tr>');
    },
    error: function () { $('#refRows').html('<tr><td colspan="5"><div class="empty">Could not load referrals.</div></td></tr>'); }
  });

  $(document).on('click', '[data-details]', function () {
    location.href = '/Referrals/Details/' + $(this).data('details');
  });
});
