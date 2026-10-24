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
    // Validate against the definition (required, email format, lengths,
    // ranges, custom regex). Failures show inline, like every other form
    // on the site: red border + message under the field.
    var errors = CMSFormRenderer.validate($('#dfRenderForm'), formDef);
    CMSFormRenderer.clearErrors($('#dfRenderBody'));
    if (errors.length) {
      CMSFormRenderer.showErrors($('#dfRenderBody'), errors);
      CMS.toast('Please fix the highlighted fields.', 'error');
      CMSFormRenderer.showField($('#dfRenderBody'), errors[0].fieldKey);
      return;
    }
    var data = CMSFormRenderer.collect($('#dfRenderForm'));
    $('#dfResultJson').text(JSON.stringify(data, null, 2));
    $('#dfResult').prop('hidden', false);
    CMS.toast('Form submitted (preview).', 'success');
  });

  $('#dfRenderForm').on('reset', function () {
    setTimeout(function () {
      $('#dfResult').prop('hidden', true);
      CMSFormRenderer.clearErrors($('#dfRenderBody'));
    }, 0);
  });
});
