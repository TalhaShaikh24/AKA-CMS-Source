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
   Require / MakeOptional rewrite a field's required flag the same
   way, and Disable / Enable are applied to the rendered controls
   after render (their values still submit). The server applies the
   same rules when it validates the submission.
   Edit mode shows everything: hiding a section there would drop its
   saved values on save. If the workflow call fails (no workflow, no
   permission, SQL not run yet) the whole form shows — the safe
   default.
   Workflow step engine (2026-11-07): ?instanceId=<id> opens the form
   at the instance's current step, with that step's sections (a
   disabled section shows read-only) and the step's buttons under
   the form instead of Submit. ?workflowId=<id> starts a new case at
   the workflow's start step: the first button press saves the entry,
   starts the instance on it, then moves it on. The start step must
   show the required fields — the first save validates against the
   workflow's own sections, because there is no instance yet. */

$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initValidation(document);

  var formId = $('#dfFormId').val();
  var editId = null;
  var instanceId = null;   // workflow continue mode (?instanceId=)
  var workflowId = null;   // workflow start mode (?workflowId=)
  var wfMode = null;       // 'continue' | 'start' | null
  var wfInstance = null;   // instance detail in continue mode
  var wfSubmissionId = null;
  var wfEntryValues = null; // saved values, merged back on a step save
  var wfStepActions = [];  // buttons of the current step
  var wfDisabledKeys = [];

  // Workflow actions, applied to the definition before render.
  // A section is hidden when the workflow says IsVisible = false;
  // Hide/Show actions then run in order on top (a Hide action on a
  // field hides just that field, on a section hides the whole
  // section). A field is hidden when it is hidden itself or any
  // ancestor section is hidden. Require / MakeOptional rewrite the
  // field's isRequired, so the asterisk and the client-side
  // validation both follow the workflow. Disable / Enable cannot
  // live in the definition (the renderer has no disabled flag), so
  // they are returned here and applied to the DOM after render —
  // the value still submits, because the collector reads disabled
  // inputs too. Returns the keys to disable after render.
  function applyWorkflowToFormDef(wf) {
    var hiddenSections = {};
    var hiddenFields = {};
    var requiredMap = {};   // fieldKey -> true (Require) / false (MakeOptional)
    var disabledMap = {};   // fieldKey -> true while a Disable is in force
    var byKey = {};
    (formDef.fields || []).forEach(function (f) { byKey[f.fieldKey] = f; });
    // Every field below a section, nested sections included.
    function descendantsOf(sectionKey) {
      var out = [];
      (formDef.fields || []).forEach(function (f) {
        var cursor = f;
        while (cursor && cursor.parentKey) {
          if (cursor.parentKey === sectionKey) { out.push(f.fieldKey); break; }
          cursor = byKey[cursor.parentKey];
        }
      });
      return out;
    }
    // A null target means the whole section; otherwise one field.
    function applyToTargets(sectionKey, targetKey, fn) {
      if (targetKey) { fn(targetKey); return; }
      descendantsOf(sectionKey).forEach(fn);
    }
    (wf.sections || []).forEach(function (s) {
      if (!s.isVisible) hiddenSections[s.sectionKey] = true;
      // A section the step disables shows read-only: its fields are
      // disabled after render (their values still submit).
      if (s.isEnable === false) descendantsOf(s.sectionKey).forEach(function (k) { disabledMap[k] = true; });
      (s.actions || []).forEach(function (a) {
        if (a.actionType === 'Hide') {
          if (a.targetKey) hiddenFields[a.targetKey] = true;
          else hiddenSections[s.sectionKey] = true;
        } else if (a.actionType === 'Show') {
          if (a.targetKey) delete hiddenFields[a.targetKey];
          else delete hiddenSections[s.sectionKey];
        } else if (a.actionType === 'Disable') {
          applyToTargets(s.sectionKey, a.targetKey, function (k) { disabledMap[k] = true; });
        } else if (a.actionType === 'Enable') {
          applyToTargets(s.sectionKey, a.targetKey, function (k) { delete disabledMap[k]; });
        } else if (a.actionType === 'Require') {
          applyToTargets(s.sectionKey, a.targetKey, function (k) { requiredMap[k] = true; });
        } else if (a.actionType === 'MakeOptional') {
          applyToTargets(s.sectionKey, a.targetKey, function (k) { requiredMap[k] = false; });
        }
      });
    });
    function fieldHidden(f) {
      if (hiddenSections[f.fieldKey] || hiddenFields[f.fieldKey]) return true;
      var cursor = f;
      while (cursor && cursor.parentKey) {
        if (hiddenSections[cursor.parentKey] || hiddenFields[cursor.parentKey]) return true;
        cursor = byKey[cursor.parentKey];
      }
      return false;
    }
    formDef.fields = (formDef.fields || []).filter(function (f) { return !fieldHidden(f); });
    // Required follows the workflow: the asterisk renders from
    // isRequired, and validate() reads the same definition.
    formDef.fields.forEach(function (f) {
      if (requiredMap.hasOwnProperty(f.fieldKey)) f.isRequired = requiredMap[f.fieldKey];
    });
    return Object.keys(disabledMap);
  }

  // Disable the workflow-disabled fields in the rendered DOM. The
  // values still submit: collect() reads disabled inputs too.
  function applyDisabledFields($root, keys) {
    (keys || []).forEach(function (key) {
      var $wrap = $root.find('[data-fkey="' + key + '"]');
      if (!$wrap.length) return;
      $wrap.addClass('dfb-disabled');
      $wrap.find('input, select, textarea, button').prop('disabled', true);
      $wrap.find('select').trigger('change'); // let Select2 show the disabled state
    });
  }
  try {
    var qs = new URLSearchParams(window.location.search);
    editId = qs.get('edit');
    instanceId = qs.get('instanceId');
    workflowId = qs.get('workflowId');
  } catch (e) { editId = null; instanceId = null; workflowId = null; }
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
      // New entry: workflow mode (?instanceId= / ?workflowId=)
      // decides the sections and buttons; otherwise the active
      // workflow's sections, as before.
      if (instanceId) loadWorkflowContinue();
      else if (workflowId) loadWorkflowStart();
      else loadPerWorkflow();
    },
    error: function () {
      $('#dfRenderBody').html('<div class="hint">Form not found.</div>');
      return true;
    }
  });

  // Per-workflow mode (no instance): the active workflow's
  // sections, as before. Any failure renders the whole form (the
  // error handler returns true: no toast for a non-critical
  // enhancement).
  function loadPerWorkflow() {
    cmsAjax({
      url: '/api/workflows/by-form/' + formId + '/sections', method: 'GET',
      success: function (wf) {
        wfDisabledKeys = applyWorkflowToFormDef(wf);
        CMSFormRenderer.render($('#dfRenderBody'), formDef);
        applyDisabledFields($('#dfRenderBody'), wfDisabledKeys);
      },
      error: function () {
        CMSFormRenderer.render($('#dfRenderBody'), formDef);
        return true;
      }
    });
  }

  // One step's sections + buttons: apply the sections to the
  // definition, show the step's buttons, then run done(). A failure
  // renders the whole form and no buttons.
  function loadWorkflowStep(stepSectionsUrl, actionsUrl, done) {
    cmsAjax({
      url: stepSectionsUrl, method: 'GET',
      success: function (wf) {
        wfDisabledKeys = applyWorkflowToFormDef(wf);
        loadStepActions(actionsUrl, done);
      },
      error: function () { loadStepActions(actionsUrl, done); return true; }
    });
  }

  function loadStepActions(actionsUrl, done) {
    if (!actionsUrl) { renderStepButtons([]); if (done) done(); return; }
    cmsAjax({
      url: actionsUrl, method: 'GET',
      success: function (res) {
        // Two shapes: instance actions come wrapped ({ actions: [...] }),
        // step actions come as a bare list. Accept both.
        wfStepActions = Array.isArray(res) ? res : ((res && res.actions) || []);
        renderStepButtons(wfStepActions);
        if (done) done();
      },
      error: function () { renderStepButtons([]); if (done) done(); return true; }
    });
  }

  // The step's buttons replace the form's own Submit row.
  function renderStepButtons(actions) {
    var $box = $('#dfStepActions');
    // Continue mode only: the request already exists, so its
    // history (flow chart + log) is available.
    var histBtn = instanceId ? ' <button type="button" class="btn btn-ghost" data-wfhistory="1">History</button>' : '';
    if (!actions.length) {
      $box.html('<span class="hint">This step has no buttons.</span> <a class="btn btn-ghost" href="/MyTasks">Back to My Tasks</a>' + histBtn).show();
      $('#dfDefaultActions').hide();
      return;
    }
    $box.html(actions.map(function (a) {
      return '<button type="button" class="btn btn-primary" data-wfaction="' + esc(a.actionCode) + '">' + esc(a.actionTitle) + '</button>';
    }).join('') + ' <a class="btn btn-ghost" href="/MyTasks">Back to My Tasks</a>' + histBtn).show();
    $('#dfDefaultActions').hide();
  }

  $(document).on('click', '[data-wfhistory]', function () {
    if (!instanceId) return;
    window.WorkflowHistory.open({
      modal: '#dfHistoryModal', titleEl: '#dfHistoryTitle', bodyEl: '#dfHistoryBody',
      instanceId: instanceId,
      title: 'History — ' + (wfInstance
        ? wfInstance.workflowName + ' — ' + (wfInstance.currentStepTitle || wfInstance.currentStepCode)
        : 'Request')
    });
  });

  // Workflow continue mode (?instanceId=): the entry already exists;
  // open it at the instance's current step, with that step's sections
  // and buttons. The entry's saved values are merged back on save,
  // so fields hidden at this step are not lost by the PUT.
  function loadWorkflowContinue() {
    wfMode = 'continue';
    cmsAjax({
      url: '/api/workflow-instances/' + instanceId, method: 'GET',
      fallbackMsg: 'Could not load task.',
      success: function (inst) {
        wfInstance = inst;
        wfSubmissionId = inst.submissionId;
        $('#dfTitle').text(formDef.title + ' — ' + (inst.currentStepTitle || inst.currentStepCode));
        if (!inst.submissionId) { $('#dfRenderBody').html('<div class="hint">This task has no form entry.</div>'); return; }
        cmsAjax({
          url: '/api/dynamic-forms/submissions/' + inst.submissionId, method: 'GET',
          fallbackMsg: 'Could not load entry.',
          success: function (entry) {
            wfEntryValues = entry.values || {};
            injectScalarDefaults(entry);
            loadWorkflowStep(
              '/api/workflows/by-form/' + formId + '/sections?instanceId=' + instanceId,
              '/api/workflow-instances/' + instanceId + '/actions',
              function () {
                CMSFormRenderer.render($('#dfRenderBody'), formDef);
                prefillAfterRender(entry);
                applyDisabledFields($('#dfRenderBody'), wfDisabledKeys);
              });
          },
          error: function () {
            $('#dfRenderBody').html('<div class="hint">Entry not found.</div>');
            return true;
          }
        });
      },
      error: function () {
        $('#dfRenderBody').html('<div class="hint">Task not found.</div>');
        return true;
      }
    });
  }

  // Step rows override visibility/enablement; the workflow's own
  // sections keep their field actions. No step rows = workflow as-is.
  function mergeStartSections(base, stepSecs) {
    var override = {};
    (stepSecs || []).forEach(function (ss) { override[ss.sectionKey] = ss; });
    var merged = (base.sections || []).map(function (s) {
      var o = override[s.sectionKey];
      return o
        ? { sectionKey: s.sectionKey, isVisible: o.isVisible, isEnable: o.isEnable, displayOrder: o.displayOrder, actions: s.actions || [] }
        : s;
    });
    (stepSecs || []).forEach(function (ss) {
      if (!merged.some(function (m) { return m.sectionKey === ss.sectionKey; }))
        merged.push({ sectionKey: ss.sectionKey, isVisible: ss.isVisible, isEnable: ss.isEnable, displayOrder: ss.displayOrder, actions: [] });
    });
    return { workflowId: base.workflowId, sections: merged };
  }

  // Workflow start mode (?workflowId=): the form opens at the
  // workflow's start step. The entry does not exist yet — it is
  // created by the first button press, then the instance starts on
  // it and the button moves it on.
  function loadWorkflowStart() {
    wfMode = 'start';
    cmsAjax({
      url: '/api/workflows/' + workflowId + '/steps', method: 'GET',
      fallbackMsg: 'Could not load workflow steps.',
      success: function (res) {
        var start = (res || []).filter(function (s) { return s.isStart; })[0];
        if (!start) {
          CMS.toast('This workflow has no start step.', 'error');
          loadPerWorkflow();
          return;
        }
        $('#dfTitle').text(formDef.title + ' — ' + start.stepTitle);
        cmsAjax({
          url: '/api/workflows/by-form/' + formId + '/sections', method: 'GET',
          success: function (wf) {
            var base = wf;
            cmsAjax({
              url: '/api/workflows/steps/' + start.workflowStepId + '/sections', method: 'GET',
              success: function (stepSecs) {
                wfDisabledKeys = applyWorkflowToFormDef(mergeStartSections(base, stepSecs));
                loadStepActions('/api/workflows/steps/' + start.workflowStepId + '/actions', function () {
                  CMSFormRenderer.render($('#dfRenderBody'), formDef);
                  applyDisabledFields($('#dfRenderBody'), wfDisabledKeys);
                });
              },
              error: function () {
                wfDisabledKeys = applyWorkflowToFormDef(base);
                loadStepActions('/api/workflows/steps/' + start.workflowStepId + '/actions', function () {
                  CMSFormRenderer.render($('#dfRenderBody'), formDef);
                  applyDisabledFields($('#dfRenderBody'), wfDisabledKeys);
                });
                return true;
              }
            });
          },
          error: function () {
            CMSFormRenderer.render($('#dfRenderBody'), formDef);
            return true;
          }
        });
      },
      error: function () {
        loadPerWorkflow();
        return true;
      }
    });
  }

  // File inputs travel as real files, not filenames: the filename the
  // collector produced for a file field is dropped, and the chosen
  // file (if any) is appended as "file_{fieldKey}".
  function buildSubmissionFormData(data) {
    var fd = new FormData();
    (formDef.fields || []).forEach(function (f) {
      if (f.fieldType !== 'file') return;
      var input = $('#dfRenderForm').find('[name="' + f.fieldKey + '"]')[0];
      if (input && input.files && input.files.length) fd.append('file_' + f.fieldKey, input.files[0]);
      delete data[f.fieldKey];
    });
    fd.append('values', JSON.stringify(data));
    return fd;
  }

  // One step button press: validate, save the entry, then move the
  // instance. In start mode the entry and the instance are created
  // by this press, in that order.
  function executeStepAction(actionCode) {
    if (!formDef || !wfStepActions.length) return;
    var errors = CMSFormRenderer.validate($('#dfRenderForm'), formDef);
    CMSFormRenderer.clearErrors($('#dfRenderBody'));
    if (errors.length) {
      CMSFormRenderer.showErrors($('#dfRenderBody'), errors);
      CMS.toast('Please fix the highlighted fields.', 'error');
      CMSFormRenderer.showField($('#dfRenderBody'), errors[0].fieldKey);
      return;
    }
    var data = CMSFormRenderer.collect($('#dfRenderForm'));
    // Continue mode: values the step hides stay in the entry — merge
    // the saved values under the collected ones before the PUT.
    if (wfMode === 'continue' && wfEntryValues) {
      data = $.extend({}, wfEntryValues, data);
    }
    var fd = buildSubmissionFormData(data);
    var $btns = $('#dfStepActions button').prop('disabled', true);
    var saveReq = wfMode === 'continue'
      ? { url: '/api/dynamic-forms/submissions/' + wfSubmissionId + '?instanceId=' + instanceId, method: 'PUT' }
      : { url: '/api/dynamic-forms/' + formId + '/submissions', method: 'POST' };
    cmsAjax({
      url: saveReq.url, method: saveReq.method, data: fd,
      fallbackMsg: 'Could not save form.',
      success: function (saved) {
        if (wfMode === 'start') {
          wfSubmissionId = saved.submissionId;
          cmsAjax({
            url: '/api/workflow-instances', method: 'POST', json: true,
            data: { workflowId: Number(workflowId), submissionId: wfSubmissionId },
            fallbackMsg: 'Entry saved, but the workflow could not start.',
            success: function (inst) { moveInstance(inst.workflowInstanceId, actionCode, $btns); },
            error: function () { $btns.prop('disabled', false); return true; }
          });
        } else {
          moveInstance(Number(instanceId), actionCode, $btns);
        }
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
        $btns.prop('disabled', false);
        return false;
      }
    });
  }

  function moveInstance(id, actionCode, $btns) {
    cmsAjax({
      url: '/api/workflow-instances/' + id + '/actions/' + encodeURIComponent(actionCode),
      method: 'POST', json: true, data: {},
      fallbackMsg: 'Could not move the request.',
      success: function () {
        CMS.toast('Moved to the next step.', 'success');
        window.location.href = '/MyTasks';
      },
      error: function () { if ($btns) $btns.prop('disabled', false); return true; }
    });
  }

  $(document).on('click', '[data-wfaction]', function () {
    executeStepAction($(this).data('wfaction'));
  });

  $('#dfRenderForm').on('submit', function (e) {
    e.preventDefault();
    if (!formDef) return;
    // Workflow mode has its own buttons; the form's own Submit is hidden.
    if (wfMode) return;
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
    var fd = buildSubmissionFormData(data);
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
