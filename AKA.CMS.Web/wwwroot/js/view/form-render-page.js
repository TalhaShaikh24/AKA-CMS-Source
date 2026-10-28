/* Dynamic Form render page — loads a form definition and renders it with
   the app theme via CMSFormRenderer. Submit validates client-side, then
   really saves the entry (POST /api/dynamic-forms/{id}/submissions):
   values go as one JSON part, file fields as real file parts. */
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
    // File inputs travel as real files, not filenames: the filename the
    // collector produced for a file field is dropped, and the chosen
    // file (if any) is appended as "file_{fieldKey}".
    var fd = new FormData();
    (formDef.fields || []).forEach(function (f) {
      if (f.fieldType !== 'file') return;
      var input = $('#dfRenderForm').find('[name="' + f.fieldKey + '"]')[0];
      if (input && input.files && input.files.length) fd.append('file_' + f.fieldKey, input.files[0]);
      delete data[f.fieldKey];
    });
    fd.append('values', JSON.stringify(data));
    var $btn = $('#dfRenderForm').find('button[type="submit"]');
    $btn.prop('disabled', true);
    cmsAjax({
      url: '/api/dynamic-forms/' + formId + '/submissions', method: 'POST',
      data: fd,
      fallbackMsg: 'Could not submit form.',
      // Entry saved: take the user back to the Dynamic Forms list
      // instead of staying on the fill page with a success block.
      success: function () {
        window.location.href = '/DynamicForms';
      },
      error: function (xhr) {
        // Server-side validation comes back per field (the same shape
        // the middleware builds for FluentValidation): show it inline
        // instead of a generic toast.
        var body = xhr.responseJSON || null;
        var errs = body && body.errors;
        if (errs) {
          var mapped = Object.keys(errs).map(function (k) {
            var msgs = errs[k];
            return { fieldKey: k, message: $.isArray(msgs) ? msgs[0] : msgs };
          });
          CMSFormRenderer.clearErrors($('#dfRenderBody'));
          CMSFormRenderer.showErrors($('#dfRenderBody'), mapped);
          CMS.toast('Please fix the highlighted fields.', 'error');
          if (mapped.length) CMSFormRenderer.showField($('#dfRenderBody'), mapped[0].fieldKey);
          return true;
        }
        return false;
      }
    }).always(function () { $btn.prop('disabled', false); });
  });

  $('#dfRenderForm').on('reset', function () {
    setTimeout(function () {
      CMSFormRenderer.clearErrors($('#dfRenderBody'));
    }, 0);
  });
});
