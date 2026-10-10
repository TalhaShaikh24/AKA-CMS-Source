/* ==========================================================================
   Dashboard — matches the CMO design: crisis alert, stat cards,
   module cards, recent activity timeline, quick actions.
   API-wired (no demo data).
   ========================================================================== */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  $('[data-go]').on('click', function () { location.href = $(this).data('go'); });

  var user = (window.cmsAuth && window.cmsAuth.getUser && window.cmsAuth.getUser()) || {};
  var name = user.username || user.userName || 'there';
  var hour = new Date().getHours();
  var greet = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
  $('#dashSub').text(greet + ', ' + name + '. Here is your case management overview.');

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

  /* ---------- stats ---------- */
  cmsAjax({
    url: '/api/cases', method: 'GET', data: { page: 1, pageSize: 1 },
    success: function (res) {
      var total = (res && res.totalCount) || 0;
      $('#stActive').text(total);
      $('#stNew').text(total);
    },
    error: function () { $('#stActive').text('—'); $('#stNew').text('—'); }
  });
  cmsAjax({
    url: '/api/follow-ups/due', method: 'GET',
    success: function (res) {
      var list = res || [];
      $('#stFollowups').text(list.length);
    },
    error: function () { $('#stFollowups').text('—'); }
  });
  $('#stLtfu').text('—');

  /* ---------- crisis alert ---------- */
  cmsAjax({
    url: '/api/cases', method: 'GET', data: { page: 1, pageSize: 100 },
    success: function (res) {
      var items = (res && res.items) || [];
      var crisis = items.filter(function (c) { return /high|critical/i.test(c.priorityLevel || ''); });
      if (crisis.length) {
        $('#crisisCount').text(crisis.length);
        $('#crisisAlert').prop('hidden', false);
        $('#openCrisisBtn').on('click', function () {
          location.href = '/Crisis/Case/' + crisis[0].caseId;
        });
      }
    }
  });

  /* ---------- recent activity ---------- */
  cmsAjax({
    url: '/api/cases', method: 'GET', data: { page: 1, pageSize: 5 },
    success: function (res) {
      var items = (res && res.items) || [];
      if (!items.length) { $('#recentActivity').html('<div class="empty">No recent activity.</div>'); return; }
      $('#recentActivity').html(items.map(function (c) {
        var d = c.createdAt ? new Date(c.createdAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : '';
        return '<div class="event"><h4>Case ' + esc(c.caseNumber || ('#' + c.caseId)) + ' — ' + esc(c.statusName || c.status) + '</h4>' +
          '<p>' + esc(d) + ' · ' + esc(c.memberName || '') + '</p></div>';
      }).join(''));
    },
    error: function () { $('#recentActivity').html('<div class="empty">Could not load activity.</div>'); }
  });
});
