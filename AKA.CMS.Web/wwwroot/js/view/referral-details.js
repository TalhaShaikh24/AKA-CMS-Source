/* Referral details — loaded through the global cmsAjax helper
   DIRECTLY from the Web API. Razor never touches the backend. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  $('[data-go]').on('click', function () { location.href = $(this).data('go'); });

  var id = $('#refId').val();

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function kv(k, v) { return '<div class="k">' + esc(k) + '</div><div class="v">' + esc(v == null || v === '' ? '—' : v) + '</div>'; }
  function fmtDate(d) {
    if (!d) return '—';
    try { return new Date(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }); }
    catch (e) { return d; }
  }

  // The API is case-scoped for single referrals; find it in the queue.
  cmsAjax({
    url: '/api/referrals?top=200', method: 'GET',
    fallbackMsg: 'Could not load referral.',
    success: function (res) {
      var r = (res || []).filter(function (x) { return String(x.referralId) === String(id); })[0];
      if (!r) { $('#refSummary').html('<div class="empty">Referral not found.</div>'); return; }
      $('#refNum').text(r.referralNumber + ' · ' + (r.caseNumber || ('Case #' + r.caseId)));
      $('#refSummary').html(
        kv('Service', r.referredTo) +
        kv('Case', r.caseNumber || ('#' + r.caseId)) +
        kv('Status', r.status) +
        kv('Created', fmtDate(r.createdAt)) +
        kv('Created by', r.createdByUsername)
      );
      $('#refDetails').html(
        kv('Notes', r.notes) +
        kv('SLA due', fmtDate(r.slaDueAt)) +
        kv('Rejection reason', r.rejectionReason)
      );
    },
    error: function () { $('#refSummary').html('<div class="empty">Could not load referral.</div>'); }
  });
});
