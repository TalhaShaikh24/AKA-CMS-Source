/* Dynamic Forms — list page. Data comes from /api/dynamic-forms via cmsAjax. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  function fmtDate(v) {
    if (!v) return '—';
    var d = new Date(v);
    return isNaN(d) ? '—' : d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function load() {
    cmsAjax({
      url: '/api/dynamic-forms', method: 'GET',
      fallbackMsg: 'Could not load forms.',
      success: function (res) {
        var rows = res || [];
        $('#dfCount').text(rows.length + ' form' + (rows.length === 1 ? '' : 's'));
        $('#dfTbody').html(rows.map(function (f) {
          return '<tr>' +
            '<td><strong>' + esc(f.title) + '</strong>' +
              (f.description ? '<br><span class="hint">' + esc(f.description) + '</span>' : '') + '</td>' +
            '<td><code>' + esc(f.formKey) + '</code></td>' +
            '<td>' + f.fieldCount + '</td>' +
            '<td>' + (f.isActive
              ? '<span class="pill" style="background:#e6f4ea;color:#1e7e34">Active</span>'
              : '<span class="pill">Inactive</span>') + '</td>' +
            '<td>' + fmtDate(f.updatedAt || f.createdAt) + '</td>' +
            '<td class="row-actions" style="white-space:nowrap">' +
              '<a class="btn btn-ghost btn-sm" href="/DynamicForms/Render/' + f.formId + '">Preview</a> ' +
              '<a class="btn btn-ghost btn-sm" href="/DynamicForms/Builder/' + f.formId + '" data-permission="DynamicForms:Write">Edit</a> ' +
              '<button class="btn btn-ghost btn-sm" data-deactivate="' + f.formId + '" type="button" data-permission="DynamicForms:Write"' +
                (f.isActive ? '' : ' disabled') + '>Deactivate</button>' +
            '</td></tr>';
        }).join('') || '<tr><td colspan="6" class="hint">No forms yet. Click “+ New Form” to build one.</td></tr>');
        if (window.CMS && CMS.applyPermissions) CMS.applyPermissions(document);
      }
    });
  }

  $(document).on('click', '[data-deactivate]', function () {
    var id = $(this).data('deactivate');
    if (!window.confirm('Deactivate this form? It stays in the database and can be re-activated from the builder.')) return;
    cmsAjax({
      url: '/api/dynamic-forms/' + id, method: 'DELETE',
      fallbackMsg: 'Could not deactivate form.',
      success: function () { CMS.toast('Form deactivated.', 'success'); load(); }
    });
  });

  load();
});
