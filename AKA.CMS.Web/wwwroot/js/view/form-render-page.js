/* Dynamic Form render page — loads a form definition and renders it with
   the app theme via CMSFormRenderer. Submit validates required fields and
   shows the collected values (preview of what a wired-up consumer receives). */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initValidation(document);

  var formId = $('#dfFormId').val();
  var formDef = null;

  cmsAjax({
    url: '/api/dynamic-forms/' + formId, method: 'GET',
    fallbackMsg: 'Could not load form.',
    success: function (f) {
      formDef = f;
      $('#dfTitle').text(f.title);
      $('#dfDesc').text(f.description || '');
      document.title = f.title + ' — AKA-CMS';
      CMSFormRenderer.render($('#dfRenderBody'), f);
    },
    error: function () {
      $('#dfRenderBody').html('<div class="hint">Form not found.</div>');
      return true;
    }
  });

  $('#dfRenderForm').on('submit', function (e) {
    e.preventDefault();
    if (!formDef) return;
    // Required-field validation against the definition.
    var data = CMSFormRenderer.collect($('#dfRenderForm'));
    var missing = [];
    (formDef.fields || []).forEach(function (f) {
      if (!f.isRequired) return;
      if (f.fieldType === 'heading' || f.fieldType === 'paragraph') return;
      var v = data[f.fieldKey];
      if (v == null || v === '' || (Array.isArray(v) && !v.length) || v === false) missing.push(f.label);
    });
    if (missing.length) {
      CMS.toast('Required: ' + missing.join(', '), 'error');
      return;
    }
    $('#dfResultJson').text(JSON.stringify(data, null, 2));
    $('#dfResult').prop('hidden', false);
    CMS.toast('Form submitted (preview).', 'success');
  });

  $('#dfRenderForm').on('reset', function () {
    setTimeout(function () { $('#dfResult').prop('hidden', true); }, 0);
  });
});
