/* Dynamic Form entries — list of submitted entries for one form, plus a
   detail view of every answered field. Data comes from
   /api/dynamic-forms/{id}/submissions via cmsAjax. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();

  var formId = $('#dfFormId').val();
  var formDef = null;
  var openEntryId = null;

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  function fmtDate(v) {
    if (!v) return '—';
    var d = new Date(v);
    return isNaN(d) ? '—' : d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function optionLabel(field, value) {
    var found = (field.options || []).filter(function (o) { return String(o.value) === String(value); })[0];
    return found ? found.label : value;
  }

  // One answered value rendered for the detail view.
  function fmtValue(field, value, entryId) {
    if (value === null || value === undefined || value === '') return '—';
    if (field.fieldType === 'file') {
      var name = String(value).split('/').pop();
      return '<button class="btn btn-ghost btn-sm" type="button" data-download-field="' + esc(field.fieldKey) +
        '" data-download-entry="' + entryId + '">' + esc(name) + ' ⬇</button>';
    }
    if (field.fieldType === 'grid') {
      var rows = $.isArray(value) ? value : [];
      var cols = field.gridColumns || [];
      if (!rows.length) return '—';
      var head = cols.map(function (c) { return '<th>' + esc(c.label) + '</th>'; }).join('');
      var body = rows.map(function (r) {
        return '<tr>' + cols.map(function (c) {
          var v = r[c.key];
          return '<td>' + esc(v == null ? '' : v) + '</td>';
        }).join('') + '</tr>';
      }).join('');
      return '<table class="table" style="margin-top:6px"><thead><tr>' + head + '</tr></thead><tbody>' + body + '</tbody></table>';
    }
    if (typeof value === 'boolean') return value ? 'Yes' : 'No';
    if ($.isArray(value)) {
      if (!value.length) return '—';
      return esc(value.map(function (v) { return optionLabel(field, v); }).join(', '));
    }
    if (field.fieldType === 'select' || field.fieldType === 'radio' || field.fieldType === 'lookup')
      return esc(optionLabel(field, value));
    return esc(value);
  }

  function load() {
    cmsAjax({
      url: '/api/dynamic-forms/' + formId + '/submissions', method: 'GET',
      fallbackMsg: 'Could not load entries.',
      success: function (rows) {
        rows = rows || [];
        $('#dfCount').text(rows.length + ' entr' + (rows.length === 1 ? 'y' : 'ies'));
        $('#dfTbody').html(rows.map(function (e) {
          return '<tr>' +
            '<td><strong>#' + e.submissionId + '</strong></td>' +
            '<td>' + fmtDate(e.submittedAt) + '</td>' +
            '<td>' + esc(e.submittedByName || '—') + '</td>' +
            '<td>' + e.valueCount + '</td>' +
            '<td class="row-actions" style="white-space:nowrap">' +
              '<button class="btn btn-ghost btn-sm" type="button" data-view="' + e.submissionId + '">View</button> ' +
              '<button class="btn btn-ghost btn-sm" type="button" data-delete="' + e.submissionId + '" data-permission="DynamicForms:Write">Delete</button>' +
            '</td></tr>';
        }).join('') || '<tr><td colspan="5" class="hint">No entries yet. Fill the form to create the first one.</td></tr>');
        if (window.CMS && CMS.applyPermissions) CMS.applyPermissions(document);
      }
    });
  }

  function showDetail(entry) {
    openEntryId = entry.submissionId;
    $('#dfDetailTitle').text('Entry #' + entry.submissionId);
    $('#dfDetailMeta').text('Submitted ' + fmtDate(entry.submittedAt) + ' by ' + (entry.submittedByName || '—'));
    var html = '';
    (formDef.fields || []).forEach(function (f) {
      if (f.fieldType === 'section') {
        html += '<h4 style="margin:16px 0 8px">' + esc(f.label) + '</h4>';
        return;
      }
      // Headings, paragraphs, buttons and links are layout, not answers.
      if (f.fieldType === 'heading' || f.fieldType === 'paragraph' || f.fieldType === 'button' || f.fieldType === 'link') return;
      var v = entry.values ? entry.values[f.fieldKey] : undefined;
      html += '<div class="field" style="margin-bottom:10px"><label class="label">' + esc(f.label) +
        (f.fieldType === 'hidden' ? ' <span class="pill">hidden</span>' : '') + '</label>' +
        '<div>' + fmtValue(f, v, entry.submissionId) + '</div></div>';
    });
    $('#dfDetailBody').html(html || '<div class="hint">No answers in this entry.</div>');
    $('#dfDetailCard').prop('hidden', false);
    document.getElementById('dfDetailCard').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  $(document).on('click', '[data-view]', function () {
    var id = $(this).data('view');
    cmsAjax({
      url: '/api/dynamic-forms/submissions/' + id, method: 'GET',
      fallbackMsg: 'Could not load entry.',
      success: showDetail
    });
  });

  $(document).on('click', '[data-delete]', function () {
    var id = $(this).data('delete');
    if (!window.confirm('Delete this entry? Its uploaded files are deleted too.')) return;
    cmsAjax({
      url: '/api/dynamic-forms/submissions/' + id, method: 'DELETE',
      fallbackMsg: 'Could not delete entry.',
      success: function () {
        CMS.toast('Entry deleted.', 'success');
        if (openEntryId === id) { openEntryId = null; $('#dfDetailCard').prop('hidden', true); }
        load();
      }
    });
  });

  // File downloads need the bearer token, so they go through fetch
  // (a plain link cannot carry the Authorization header).
  $(document).on('click', '[data-download-field]', function () {
    var entryId = $(this).data('download-entry');
    var fieldKey = $(this).data('download-field');
    var tokens = window.cmsAuth ? window.cmsAuth.getTokens() : null;
    var base = (window.CMS_API_BASE_URL || '').replace(/\/+$/, '');
    var url = base + '/api/dynamic-forms/submissions/' + entryId + '/files/' + encodeURIComponent(fieldKey);
    fetch(url, { headers: tokens ? { 'Authorization': 'Bearer ' + tokens.accessToken } : {} })
      .then(function (res) {
        if (!res.ok) throw new Error('download failed');
        var disp = res.headers.get('Content-Disposition') || '';
        var m = /filename\*?=(?:UTF-8'')?("?)([^";]+)\1/.exec(disp);
        var name = m ? decodeURIComponent(m[2]) : fieldKey;
        return res.blob().then(function (blob) { return { blob: blob, name: name }; });
      })
      .then(function (r) {
        var a = document.createElement('a');
        a.href = URL.createObjectURL(r.blob);
        a.download = r.name;
        document.body.appendChild(a);
        a.click();
        a.remove();
        setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
      })
      .catch(function () { CMS.toast('Could not download file.', 'error'); });
  });

  cmsAjax({
    url: '/api/dynamic-forms/' + formId, method: 'GET',
    fallbackMsg: 'Could not load form.',
    success: function (f) {
      formDef = f;
      $('#dfTitle').text('Entries — ' + f.title);
      $('#dfDesc').text(f.description || '');
      document.title = 'Entries — ' + f.title + ' — AKA-CMS';
      load();
    },
    error: function () {
      $('#dfTbody').html('<tr><td colspan="5" class="hint">Form not found.</td></tr>');
      return true;
    }
  });
});
