/* Workflows — list + create/edit modal. Data comes from /api/workflows
   via cmsAjax. Each section has a Show / Hide switch plus an Actions
   list: one row per action (type + target field inside the section),
   saved as sections[].actions[] and applied by the render page and
   by server-side validation on submit. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);

  var editingId = null;        // workflow id being edited, null = new
  var formsLoaded = false;     // form dropdown options populated once
  var formSections = [];       // sections of the selected form, in form order
  var formFields = [];         // all fields of the selected form (action targets)
  var sectionVisible = {};     // sectionKey -> bool (what the switches say)
  var sectionActions = {};     // sectionKey -> [{ actionType, targetKey }] in row order
  var savedVisibility = null;  // visibility from the workflow being edited
  var savedActions = null;     // actions from the workflow being edited

  // Action types the API allowlists (SP 34 + WorkflowService).
  var ACTION_TYPES = ['Show', 'Hide', 'Disable', 'Enable', 'Require', 'MakeOptional'];
  // Display-only field types can never be an action target.
  var NON_TARGET_TYPES = { heading: 1, paragraph: 1, link: 1, button: 1, hidden: 1 };

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  function fmtDate(v) {
    if (!v) return '—';
    var d = new Date(v);
    return isNaN(d) ? '—' : d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  /* ---------------- list ---------------- */
  function load() {
    cmsAjax({
      url: '/api/workflows', method: 'GET',
      fallbackMsg: 'Could not load workflows.',
      success: function (res) {
        var rows = res || [];
        $('#wfCount').text(rows.length + ' workflow' + (rows.length === 1 ? '' : 's'));
        $('#wfTbody').html(rows.map(function (w) {
          return '<tr>' +
            '<td><strong>' + esc(w.workflowName) + '</strong></td>' +
            '<td>' + esc(w.formTitle) + '<br><span class="hint"><code>' + esc(w.formKey) + '</code></span></td>' +
            '<td>' + w.sectionCount + '</td>' +
            '<td>' + (w.isActive
              ? '<span class="pill" style="background:#e6f4ea;color:#1e7e34">Active</span>'
              : '<span class="pill">Inactive</span>') + '</td>' +
            '<td class="row-actions" style="white-space:nowrap">' +
              '<a class="btn btn-ghost btn-sm" href="/Workflows/Manage/' + w.workflowId + '" data-permission="Workflows:Write">Manage</a> ' +
              (w.isActive ? '<button class="btn btn-ghost btn-sm" data-start="' + w.workflowId + '" data-form="' + w.formId + '" type="button" data-permission="WorkflowInstances:Read">Start</button> ' : '') +
              '<button class="btn btn-ghost btn-sm" data-edit="' + w.workflowId + '" type="button" data-permission="Workflows:Write">Edit</button> ' +
              '<button class="btn btn-ghost btn-sm" data-del="' + w.workflowId + '" type="button" data-permission="Workflows:Write">Delete</button>' +
            '</td></tr>';
        }).join('') || '<tr><td colspan="5" class="hint">No workflows yet. Click “+ New Workflow” to create one.</td></tr>');
        if (window.CMS && CMS.applyPermissions) CMS.applyPermissions(document);
      }
    });
  }

  /* ---------------- form dropdown ----------------
     Only active forms: the save SP rejects a workflow on an inactive
     form, so offering one would only end in a 400. */
  function loadForms(onDone) {
    cmsAjax({
      url: '/api/dynamic-forms', method: 'GET',
      fallbackMsg: 'Could not load forms.',
      success: function (res) {
        var forms = (res || []).filter(function (f) { return f.isActive; });
        $('#wfFormSel').html('<option></option>' + forms.map(function (f) {
          return '<option value="' + f.formId + '">' + esc(f.title) + '</option>';
        }).join(''));
        formsLoaded = true;
        CMS.initSelect2(document);
        if (typeof onDone === 'function') onDone();
      }
    });
  }

  /* ---------------- sections of the selected form ---------------- */
  function loadSections(formId) {
    if (!formId) { formSections = []; sectionVisible = {}; $('#wfSectionsWrap').hide(); return; }
    cmsAjax({
      url: '/api/dynamic-forms/' + formId, method: 'GET',
      fallbackMsg: 'Could not load form sections.',
      success: function (form) {
        // Sections are fields with fieldType 'section', in the form's
        // own order (sortOrder). Nested sections keep their own key.
        // All fields are kept too: an action's target is a field
        // inside its section (parentKey = the section key).
        formFields = (form.fields || []).slice()
          .sort(function (a, b) { return (a.sortOrder || 0) - (b.sortOrder || 0); });
        formSections = formFields
          .filter(function (f) { return f.fieldType === 'section'; });
        sectionVisible = {};
        sectionActions = {};
        formSections.forEach(function (s) {
          // Editing: keep the saved choice; new: everything shows.
          sectionVisible[s.fieldKey] = savedVisibility && savedVisibility.hasOwnProperty(s.fieldKey)
            ? savedVisibility[s.fieldKey] : true;
          // Editing: keep the saved actions (already in sort order);
          // new: no actions.
          sectionActions[s.fieldKey] = savedActions && savedActions[s.fieldKey]
            ? savedActions[s.fieldKey].slice() : [];
        });
        savedVisibility = null;
        savedActions = null;
        renderSections();
      },
      error: function () { $('#wfSectionsWrap').hide(); }
    });
  }

  function renderSections() {
    if (!formSections.length) {
      $('#wfSections').html('<div class="hint">This form has no sections — every field always shows.</div>');
    } else {
      $('#wfSections').html(formSections.map(function (s) {
        var visible = sectionVisible[s.fieldKey] !== false;
        return '<div class="wf-sec-block" data-secblock="' + esc(s.fieldKey) + '">' +
          '<div class="wf-sec-row">' +
          '<div class="sec-name"><strong>' + esc(s.label) + '</strong><br><code>' + esc(s.fieldKey) + '</code></div>' +
          '<div class="seg wf-seg">' +
            '<button type="button" data-sec="' + esc(s.fieldKey) + '" data-vis="true" class="' + (visible ? 'sel' : '') + '">Show</button>' +
            '<button type="button" data-sec="' + esc(s.fieldKey) + '" data-vis="false" class="' + (visible ? '' : 'sel') + '">Hide</button>' +
          '</div></div>' +
          '<div class="wf-actions">' +
            '<div class="wf-act-head"><span class="hint">Actions on load</span> ' +
            '<button type="button" class="btn btn-ghost btn-sm wf-act-add" data-add-act="' + esc(s.fieldKey) + '">+ Add action</button></div>' +
            '<div class="wf-act-list" data-actlist="' + esc(s.fieldKey) + '"></div>' +
          '</div></div>';
      }).join(''));
      formSections.forEach(function (s) { renderActions(s.fieldKey); });
    }
    $('#wfSectionsWrap').show();
  }

  /* Fields an action of this section may target: its direct children
     that take input (a nested section is a target too — hiding it
     hides everything inside it). Display-only types are excluded. */
  function sectionTargetFields(sectionKey) {
    return formFields.filter(function (f) {
      return (f.parentKey || null) === sectionKey && !NON_TARGET_TYPES[f.fieldType];
    });
  }

  function actionRowHtml(sectionKey, idx, action) {
    var targets = sectionTargetFields(sectionKey);
    return '<div class="wf-act-row">' +
      '<select class="input wf-act-type" data-sec="' + esc(sectionKey) + '" data-idx="' + idx + '">' +
        ACTION_TYPES.map(function (t) {
          return '<option value="' + t + '"' + (action.actionType === t ? ' selected' : '') + '>' + t + '</option>';
        }).join('') +
      '</select>' +
      '<select class="input wf-act-target" data-sec="' + esc(sectionKey) + '" data-idx="' + idx + '">' +
        '<option value="">Whole section</option>' +
        targets.map(function (f) {
          return '<option value="' + esc(f.fieldKey) + '"' +
            (action.targetKey === f.fieldKey ? ' selected' : '') + '>' +
            esc(f.label) + ' (' + esc(f.fieldKey) + ')</option>';
        }).join('') +
      '</select>' +
      '<button type="button" class="btn btn-ghost btn-sm wf-act-del" data-sec="' + esc(sectionKey) + '" data-idx="' + idx + '" title="Remove action">✕</button>' +
    '</div>';
  }

  // Rebuild one section's action rows from state (add/remove only —
  // typing in a row updates state without a rebuild, so focus stays).
  function renderActions(sectionKey) {
    var list = (sectionActions[sectionKey] || []);
    $('[data-actlist="' + sectionKey + '"]').html(list.map(function (a, i) {
      return actionRowHtml(sectionKey, i, a);
    }).join('') || '<div class="hint">No actions — this section shows as-is.</div>');
  }

  // Add action row: a new row defaults to Hide on the whole section.
  $(document).on('click', '.wf-act-add', function () {
    var sec = $(this).data('add-act');
    (sectionActions[sec] = sectionActions[sec] || []).push({ actionType: 'Hide', targetKey: null });
    renderActions(sec);
  });

  // Remove action row.
  $(document).on('click', '.wf-act-del', function () {
    var sec = $(this).data('sec');
    var idx = Number($(this).data('idx'));
    (sectionActions[sec] || []).splice(idx, 1);
    renderActions(sec);
  });

  // Type / target change: state only, no rebuild.
  $(document).on('change', '.wf-act-type, .wf-act-target', function () {
    var $el = $(this);
    var sec = $el.data('sec');
    var idx = Number($el.data('idx'));
    var row = (sectionActions[sec] || [])[idx];
    if (!row) return;
    if ($el.hasClass('wf-act-type')) row.actionType = $el.val();
    else row.targetKey = $el.val() || null;
  });

  // Show/Hide switch for one section.
  $(document).on('click', '.wf-seg button', function () {
    var $btn = $(this);
    sectionVisible[$btn.data('sec')] = $btn.data('vis') === true;
    $btn.siblings('button').removeClass('sel');
    $btn.addClass('sel');
  });

  $('#wfFormSel').on('change', function () {
    var formId = $(this).val();
    $('#fWfForm').removeClass('invalid');
    loadSections(formId ? Number(formId) : null);
  });

  /* ---------------- modal: new / edit ---------------- */
  function openModal(title) {
    $('#wfModalTitle').text(title);
    $('#wfModal').addClass('open');
  }

  $('#newWorkflowBtn').on('click', function () {
    editingId = null;
    savedVisibility = null;
    savedActions = null;
    $('#wfForm')[0].reset();
    $('#wfId').val('');
    $('#wfActive').prop('checked', true);
    $('#fWfName, #fWfForm').removeClass('invalid');
    formSections = []; formFields = []; sectionVisible = {}; sectionActions = {};
    $('#wfSectionsWrap').hide();
    if (!formsLoaded) loadForms();
    $('#wfFormSel').val(null).trigger('change');
    openModal('New Workflow');
  });

  // Instance-first start (2026-11-10): pressing Start creates the
  // request first (POST /api/workflow-instances, no entry yet) and
  // the form then opens on that instance (?instanceId=), where the
  // first button press saves the entry and attaches it.
  $(document).on('click', '[data-start]', function () {
    var $btn = $(this).prop('disabled', true);
    var workflowId = Number($(this).data('start'));
    var formId = Number($(this).data('form'));
    cmsAjax({
      url: '/api/workflow-instances', method: 'POST', json: true,
      data: { workflowId: workflowId },
      fallbackMsg: 'Could not start the workflow.',
      success: function (inst) {
        window.location.href = '/DynamicForms/Render/' + formId + '?instanceId=' + inst.workflowInstanceId;
      },
      // Return false: cmsAjax then shows the server's message (or the
      // fallback) — a failed Start must not fail silently.
      error: function () { $btn.prop('disabled', false); return false; }
    });
  });

  $(document).on('click', '[data-edit]', function () {
    var id = $(this).data('edit');
    cmsAjax({
      url: '/api/workflows/' + id, method: 'GET',
      fallbackMsg: 'Could not load workflow.',
      success: function (w) {
        editingId = w.workflowId;
        $('#wfId').val(w.workflowId);
        $('#wfName').val(w.workflowName);
        $('#wfCode').val(w.workflowCode || '');
        $('#wfDesc').val(w.description || '');
        $('#wfActive').prop('checked', !!w.isActive);
        $('#fWfName, #fWfForm').removeClass('invalid');
        // Saved visibility + actions, applied when the form's sections load.
        savedVisibility = {};
        savedActions = {};
        (w.sections || []).forEach(function (s) {
          savedVisibility[s.sectionKey] = !!s.isVisible;
          savedActions[s.sectionKey] = (s.actions || []).slice()
            .sort(function (a, b) { return (a.sortOrder || 0) - (b.sortOrder || 0); })
            .map(function (a) { return { actionType: a.actionType, targetKey: a.targetKey || null }; });
        });
        // The form must be selectable before its sections can load:
        // wait for the dropdown options when they are not there yet.
        if (formsLoaded) {
          $('#wfFormSel').val(String(w.formId)).trigger('change');
        } else {
          loadForms(function () { $('#wfFormSel').val(String(w.formId)).trigger('change'); });
        }
        openModal('Edit Workflow');
      }
    });
  });

  /* ---------------- save ---------------- */
  $('#wfName').on('input', function () { $('#fWfName').removeClass('invalid'); });

  $('#wfForm').on('submit', function (e) {
    e.preventDefault();
    var name = $.trim($('#wfName').val());
    var formId = $('#wfFormSel').val();
    var ok = true;
    if (!name) { $('#fWfName').addClass('invalid'); ok = false; }
    if (!formId) { $('#fWfForm').addClass('invalid'); ok = false; }
    if (!ok) { CMS.toast('Please fill in the required fields.', 'error'); return; }

    var payload = {
      workflowName: name,
      workflowCode: $.trim($('#wfCode').val()) || null,
      formId: Number(formId),
      description: $.trim($('#wfDesc').val()) || null,
      isActive: $('#wfActive').is(':checked'),
      sections: formSections.map(function (s, i) {
        return {
          sectionKey: s.fieldKey,
          isVisible: sectionVisible[s.fieldKey] !== false,
          displayOrder: i,
          // Row order is the sort order the API and the render page
          // apply the actions in.
          actions: (sectionActions[s.fieldKey] || []).map(function (a, j) {
            return { actionType: a.actionType, targetKey: a.targetKey || null, sortOrder: j };
          })
        };
      })
    };
    var isNew = !editingId;
    var $btn = $('#wfSaveBtn').prop('disabled', true);
    cmsAjax({
      url: isNew ? '/api/workflows' : '/api/workflows/' + editingId,
      method: isNew ? 'POST' : 'PUT',
      json: true,
      data: payload,
      fallbackMsg: 'Could not save workflow.',
      success: function () {
        CMS.toast(isNew ? 'Workflow created.' : 'Workflow updated.', 'success');
        $('#wfModal').removeClass('open');
        load();
      }
    }).always(function () { $btn.prop('disabled', false); });
  });

  /* ---------------- delete (soft) ---------------- */
  $(document).on('click', '[data-del]', function () {
    var id = $(this).data('del');
    if (!window.confirm('Delete this workflow? The form itself is not affected.')) return;
    cmsAjax({
      url: '/api/workflows/' + id, method: 'DELETE',
      fallbackMsg: 'Could not delete workflow.',
      success: function () { CMS.toast('Workflow deleted.', 'success'); load(); }
    });
  });

  loadForms();
  load();
});
