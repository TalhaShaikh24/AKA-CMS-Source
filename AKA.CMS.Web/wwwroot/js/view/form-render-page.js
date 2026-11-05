/* Dynamic Form render page — loads a form definition and renders it with
   the app theme via CMSFormRenderer. Submit validates client-side, then
   really saves the entry (POST /api/dynamic-forms/{id}/submissions):
   values go as one JSON part, file fields as real file parts.
   Edit mode (?edit=<submissionId>, from the Entries page) loads the
   saved entry, pre-fills the form with it, and saves with PUT
   /api/dynamic-forms/submissions/{id} instead — the physical
   FormData_ row is updated by SubmissionId, never duplicated.
   Workflow (boss request 2026-11-05): on load, a new entry first asks
   Get Workflow Sections (GET /api/workflows/by-form/{id}/sections)
   which sections show. Hidden sections are dropped from the form
   definition BEFORE rendering, so the wizard never shows an empty
   step and validation never asks for a field the user cannot see.
   The server applies the same rule when it validates the submission.
   Edit mode shows everything: hiding a section there would drop its
   saved values on save. If the workflow call fails (no workflow, no
   permission, SQL not run yet) the whole form shows — the safe
   default. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initValidation(document);

  var formId = $('#dfFormId').val();
  var editId = null;

  // Workflow hide/show, applied to the definition before render.
  // A section is hidden when the workflow says IsVisible = false;
  // Hide/Show actions then run in order on top (a Hide action on a
  // field hides just that field, on a section hides the whole
  // section). A field is hidden when it is hidden itself or any
  // ancestor section is hidden. Disable/Require actions are stored
  // by the API but not applied by this page yet — next step.
  function applyWorkflowToFormDef(wf) {
    var hiddenSections = {};
    var hiddenFields = {};
    (wf.sections || []).forEach(function (s) {
      if (!s.isVisible) hiddenSections[s.sectionKey] = true;
      (s.actions || []).forEach(function (a) {
        if (a.actionType === 'Hide') {
          if (a.targetKey) hiddenFields[a.targetKey] = true;
          else hiddenSections[s.sectionKey] = true;
        } else if (a.actionType === 'Show') {
          if (a.targetKey) delete hiddenFields[a.targetKey];
          else delete hiddenSections[s.sectionKey];
        }
      });
    });
    var byKey = {};
    (formDef.fields || []).forEach(function (f) { byKey[f.fieldKey] = f; });
    function fieldHidden(f) {
      if (hiddenSections[f.fieldKey] || hiddenFields[f.fieldKey]) return true;
      var cursor = f;
      while (cursor && cursor.parentKey) {
        if (hiddenSections[cursor.parentKey]) return true;
        cursor = byKey[cursor.parentKey];
      }
      return false;
    }
    formDef.fields = (formDef.fields || []).filter(function (f) { return !fieldHidden(f); });
  }
  try { editId = new URLSearchParams(window.location.search).get('edit'); } catch (e) { editId = null; }
  var formDef = null;

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  // Scalar values pre-fill through the renderer's defaultValue, which
  // it already honours for text/select/radio/checkbox/date inputs.
  // Multi-value and grid fields do not use defaultValue, so they are
  // pre-filled after rendering, in prefillAfterRender().
  function injectScalarDefaults(entry) {
    (formDef.fields || []).forEach(function (f) {
      var v = entry.values ? entry.values[f.fieldKey] : undefined;
      if (v === undefined || v === null) return;
      if (f.fieldType === 'checkbox') { f.defaultValue = v ? 'true' : 'false'; return; }
      if (['text', 'email', 'number', 'password', 'textarea', 'date', 'time', 'datetime',
           'select', 'radio', 'lookup', 'hidden'].indexOf(f.fieldType) >= 0) {
        f.defaultValue = typeof v === 'string' ? v : String(v);
      }
    });
  }

  function prefillAfterRender(entry) {
    (formDef.fields || []).forEach(function (f) {
      var v = entry.values ? entry.values[f.fieldKey] : undefined;
      if (v === undefined || v === null) return;
      var $root = $('#dfRenderBody');
      if (f.fieldType === 'multiselect' && $.isArray(v)) {
        $root.find('select[name="' + f.fieldKey + '"]').val(v.map(String)).trigger('change');
      } else if (f.fieldType === 'checkboxGroup' && $.isArray(v)) {
        $root.find('input[name="' + f.fieldKey + '"]').each(function () {
          $(this).prop('checked', v.map(String).indexOf(String(this.value)) >= 0);
        });
      } else if (f.fieldType === 'grid' && $.isArray(v) && v.length) {
        var $wrap = $root.find('[data-grid-field="' + f.fieldKey + '"]');
        var rows = v.map(function (row) {
          var cells = (f.gridColumns || []).map(function (c) {
            var cellVal = row[c.key] == null ? '' : row[c.key];
            if (c.type === 'select') {
              return '<td><select class="input dfb-grid-cell" data-col="' + esc(c.key) + '">' +
                '<option value="">Select…</option>' +
                (c.options || []).map(function (o) {
                  return '<option value="' + esc(o.value) + '"' +
                    (String(o.value) === String(cellVal) ? ' selected' : '') + '>' + esc(o.label) + '</option>';
                }).join('') + '</select></td>';
            }
            var t = c.type === 'number' ? 'number' : (c.type === 'date' ? 'date' : 'text');
            return '<td><input class="input dfb-grid-cell" type="' + t + '" data-col="' + esc(c.key) + '" value="' + esc(cellVal) + '"></td>';
          }).join('');
          return '<tr>' + cells + '<td class="dfb-grid-act"><button type="button" class="dfb-grid-del" title="Remove row">✕</button></td></tr>';
        }).join('');
        $wrap.find('tbody').html(rows);
      } else if (f.fieldType === 'file' && typeof v === 'string' && v) {
        var $wrap = $root.find('[data-fkey="' + f.fieldKey + '"]');
        if ($wrap.length) {
          $wrap.append('<span class="hint" style="display:block">Current file: ' + esc(String(v).split('/').pop()) +
            ' — leave the upload blank to keep it.</span>');
        }
      }
    });
  }

  cmsAjax({
    url: '/api/dynamic-forms/' + formId, method: 'GET',
    fallbackMsg: 'Could not load form.',
    success: function (f) {
      formDef = f;
      $('#dfTitle').text(f.title + (editId ? ' — Edit Entry' : ''));
      $('#dfDesc').text(f.description || '');
      document.title = f.title + (editId ? ' — Edit Entry' : '') + ' — AKA-CMS';
      if (editId) {
        $('#dfRenderForm').find('button[type="submit"]').text('Save Changes');
        cmsAjax({
          url: '/api/dynamic-forms/submissions/' + editId, method: 'GET',
          fallbackMsg: 'Could not load entry.',
          success: function (entry) {
            injectScalarDefaults(entry);
            CMSFormRenderer.render($('#dfRenderBody'), formDef);
            prefillAfterRender(entry);
          },
          error: function () {
            $('#dfRenderBody').html('<div class="hint">Entry not found.</div>');
            return true;
          }
        });
        return;
      }
      // New entry: load the active workflow first, then render
      // without the sections it hides. Any failure renders the
      // whole form (the error handler returns true: no toast for
      // a non-critical enhancement).
      cmsAjax({
        url: '/api/workflows/by-form/' + formId + '/sections', method: 'GET',
        success: function (wf) {
          applyWorkflowToFormDef(wf);
          CMSFormRenderer.render($('#dfRenderBody'), formDef);
        },
        error: function () {
          CMSFormRenderer.render($('#dfRenderBody'), formDef);
          return true;
        }
      });
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
      url: editId ? '/api/dynamic-forms/submissions/' + editId : '/api/dynamic-forms/' + formId + '/submissions',
      method: editId ? 'PUT' : 'POST',
      data: fd,
      fallbackMsg: 'Could not submit form.',
      // Entry saved: a new entry goes back to the Dynamic Forms
      // list; an edited entry goes back to that form's Entries page,
      // where the change is visible.
      success: function () {
        window.location.href = editId ? '/DynamicForms/Entries/' + formId : '/DynamicForms';
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
