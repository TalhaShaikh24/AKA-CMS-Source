/* Workflow Manage — one workflow's steps, each step's sections and
   each step's buttons. Data comes from /api/workflows via cmsAjax.
   Steps are saved one at a time; sections and buttons are saved
   wholesale per step (the whole list every time, like the workflow
   save). A step with no section rows falls back to the workflow's
   own sections — see the sections tab hint. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);

  var workflowId = Number($('#wmWorkflowId').val() || 0);
  var workflow = null;       // workflow detail (name, form)
  var steps = [];            // steps of this workflow, in order
  var roles = [];            // all roles (dropdowns)
  var formSections = [];     // sections of the workflow's form
  var formLoaded = false;    // form definition arrived (sections need it)
  var editingStepId = null;  // step in the form, null = new
  var secStepId = null;      // step selected on the sections tab
  var secState = {};         // sectionKey -> { isVisible, isEnable }
  var actStepId = null;      // step selected on the buttons tab
  var actRows = [];          // button rows of that step, in order

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  /* ---------------- tabs ---------------- */
  $('#wmTabs').on('click', '[data-tab]', function () {
    var tab = $(this).data('tab');
    $('#wmTabs button').removeClass('btn-primary').addClass('btn-ghost');
    $(this).removeClass('btn-ghost').addClass('btn-primary');
    $('.wm-tab').removeClass('active');
    $('#wmTab-' + tab).addClass('active');
  });

  /* ---------------- shared loads ---------------- */
  function loadRoles(onDone) {
    cmsAjax({
      url: '/api/roles', method: 'GET',
      fallbackMsg: 'Could not load roles.',
      success: function (res) {
        roles = (res || []).filter(function (r) { return r.isActive; });
        $('#wmStepRole').html('<option value="">— No role —</option>' + roles.map(function (r) {
          return '<option value="' + r.roleId + '">' + esc(r.description) + '</option>';
        }).join(''));
        CMS.initSelect2(document);
        if (typeof onDone === 'function') onDone();
      }
    });
  }

  function loadSteps(onDone) {
    cmsAjax({
      url: '/api/workflows/' + workflowId + '/steps', method: 'GET',
      fallbackMsg: 'Could not load steps.',
      success: function (res) {
        steps = res || [];
        renderStepsTable();
        fillStepDropdowns();
        if (typeof onDone === 'function') onDone();
      }
    });
  }

  function fillStepDropdowns() {
    var opts = steps.map(function (s) {
      return '<option value="' + s.workflowStepId + '">' + esc(s.stepTitle) + ' (' + esc(s.stepCode) + ')</option>';
    }).join('');
    $('#wmSecStepSel').html(opts);
    $('#wmActStepSel').html(opts);
    CMS.initSelect2(document);
    // Keep the selected step if it still exists, else take the first.
    if (steps.length) {
      if (!steps.some(function (s) { return s.workflowStepId === secStepId; })) secStepId = steps[0].workflowStepId;
      if (!steps.some(function (s) { return s.workflowStepId === actStepId; })) actStepId = steps[0].workflowStepId;
      // Programmatic .val() fires no change event, so load the tab data
      // here — otherwise the lists stay empty until the user re-picks
      // the step (boot race: form load and steps load finish in any order).
      $('#wmSecStepSel').val(String(secStepId)).trigger('change');
      $('#wmActStepSel').val(String(actStepId)).trigger('change');
    } else {
      secStepId = null;
      actStepId = null;
      $('#wmSecList').html('<div class="hint">Add a step first — sections are configured per step.</div>');
      $('#wmActList').html('<div class="hint">Add a step first — buttons are configured per step.</div>');
    }
  }

  function loadFormSections() {
    if (!workflow) return;
    cmsAjax({
      url: '/api/dynamic-forms/' + workflow.formId, method: 'GET',
      fallbackMsg: 'Could not load form sections.',
      success: function (form) {
        formLoaded = true;
        formSections = (form.fields || [])
          .filter(function (f) { return f.fieldType === 'section'; })
          .sort(function (a, b) { return (a.sortOrder || 0) - (b.sortOrder || 0); });
        if (secStepId) loadStepSections(secStepId);
      }
    });
  }

  /* ---------------- steps tab ---------------- */
  function renderStepsTable() {
    $('#wmStepCount').text(steps.length + ' step' + (steps.length === 1 ? '' : 's'));
    $('#wmStepsTbody').html(steps.map(function (s) {
      return '<tr>' +
        '<td><strong>' + esc(s.stepTitle) + '</strong><br><span class="hint"><code>' + esc(s.stepCode) + '</code></span></td>' +
        '<td>' + esc(s.responsibleRoleName || '—') + '</td>' +
        '<td>' + (s.isStart ? '<span class="pill" style="background:#e6f4ea;color:#1e7e34">Start</span>' : '—') + '</td>' +
        '<td>' + (s.isEnd ? '<span class="pill">End</span>' : '—') + '</td>' +
        '<td>' + (s.sla == null ? '—' : s.sla) + '</td>' +
        '<td>' + s.displayOrder + '</td>' +
        '<td class="row-actions" style="white-space:nowrap">' +
          '<button class="btn btn-ghost btn-sm" data-step-edit="' + s.workflowStepId + '" type="button" data-permission="WorkflowSteps:Write">Edit</button> ' +
          '<button class="btn btn-ghost btn-sm" data-step-del="' + s.workflowStepId + '" type="button" data-permission="WorkflowSteps:Write">Delete</button>' +
        '</td></tr>';
    }).join('') || '<tr><td colspan="7" class="hint">No steps yet. Add the first step below — one step must be the start step.</td></tr>');
    if (window.CMS && CMS.applyPermissions) CMS.applyPermissions(document);
  }

  function resetStepForm() {
    editingStepId = null;
    $('#wmStepFormTitle').text('Add Step');
    $('#wmStepForm')[0].reset();
    $('#wmStepId').val('');
    $('#wmStepOrder').val(steps.length);
    $('#fStepCode, #fStepTitle').removeClass('invalid');
  }

  $('#wmStepCancelBtn').on('click', resetStepForm);

  $(document).on('click', '[data-step-edit]', function () {
    var s = steps.filter(function (x) { return x.workflowStepId === Number($(this).data('step-edit')); })[0];
    if (!s) return;
    editingStepId = s.workflowStepId;
    $('#wmStepFormTitle').text('Edit Step');
    $('#wmStepId').val(s.workflowStepId);
    $('#wmStepCode').val(s.stepCode);
    $('#wmStepTitle').val(s.stepTitle);
    $('#wmStepRole').val(s.responsibleRoleID ? String(s.responsibleRoleID) : '').trigger('change');
    $('#wmStepSla').val(s.sla == null ? '' : s.sla);
    $('#wmStepOrder').val(s.displayOrder);
    $('#wmStepStart').prop('checked', !!s.isStart);
    $('#wmStepEnd').prop('checked', !!s.isEnd);
    $('#fStepCode, #fStepTitle').removeClass('invalid');
    $('#wmStepCode').focus();
  });

  $(document).on('click', '[data-step-del]', function () {
    var id = Number($(this).data('step-del'));
    if (!window.confirm('Delete this step? Its sections and buttons go with it.')) return;
    cmsAjax({
      url: '/api/workflows/steps/' + id, method: 'DELETE',
      fallbackMsg: 'Could not delete step.',
      success: function () { CMS.toast('Step deleted.', 'success'); loadSteps(); }
    });
  });

  $('#wmStepForm').on('submit', function (e) {
    e.preventDefault();
    var code = $.trim($('#wmStepCode').val());
    var title = $.trim($('#wmStepTitle').val());
    var ok = true;
    if (!code) { $('#fStepCode').addClass('invalid'); ok = false; }
    if (!title) { $('#fStepTitle').addClass('invalid'); ok = false; }
    if (!ok) { CMS.toast('Please fill in the required fields.', 'error'); return; }
    var sla = $.trim($('#wmStepSla').val());
    var payload = {
      stepCode: code,
      stepTitle: title,
      responsibleRoleID: $('#wmStepRole').val() ? Number($('#wmStepRole').val()) : null,
      isStart: $('#wmStepStart').is(':checked'),
      isEnd: $('#wmStepEnd').is(':checked'),
      sla: sla === '' ? null : Number(sla),
      displayOrder: Number($('#wmStepOrder').val() || 0)
    };
    var isNew = !editingStepId;
    var $btn = $('#wmStepSaveBtn').prop('disabled', true);
    cmsAjax({
      url: isNew ? '/api/workflows/' + workflowId + '/steps' : '/api/workflows/steps/' + editingStepId,
      method: isNew ? 'POST' : 'PUT',
      json: true,
      data: payload,
      fallbackMsg: 'Could not save step.',
      success: function () {
        CMS.toast(isNew ? 'Step created.' : 'Step updated.', 'success');
        resetStepForm();
        loadSteps();
      }
    }).always(function () { $btn.prop('disabled', false); });
  });

  $('#wmStepCode').on('input', function () { $('#fStepCode').removeClass('invalid'); });
  $('#wmStepTitle').on('input', function () { $('#fStepTitle').removeClass('invalid'); });

  /* ---------------- sections tab ---------------- */
  function loadStepSections(stepId) {
    secStepId = stepId;
    cmsAjax({
      url: '/api/workflows/steps/' + stepId + '/sections', method: 'GET',
      fallbackMsg: 'Could not load step sections.',
      success: function (res) {
        // Saved rows win; a section with no row shows and enables.
        secState = {};
        formSections.forEach(function (s) { secState[s.fieldKey] = { isVisible: true, isEnable: true }; });
        (res || []).forEach(function (r) {
          if (secState[r.sectionKey]) secState[r.sectionKey] = { isVisible: !!r.isVisible, isEnable: !!r.isEnable };
        });
        renderSecList();
      }
    });
  }

  function renderSecList() {
    if (!formLoaded) {
      $('#wmSecList').html('<div class="hint">Loading sections…</div>');
      return;
    }
    if (!formSections.length) {
      $('#wmSecList').html('<div class="hint">This form has no sections.</div>');
      return;
    }
    $('#wmSecList').html(formSections.map(function (s) {
      var st = secState[s.fieldKey] || { isVisible: true, isEnable: true };
      return '<div class="wm-sec-row">' +
        '<div class="sec-name"><strong>' + esc(s.label) + '</strong><br><code>' + esc(s.fieldKey) + '</code></div>' +
        '<div class="seg wm-sec-vis">' +
          '<button type="button" data-sec="' + esc(s.fieldKey) + '" data-vis="true" class="' + (st.isVisible ? 'sel' : '') + '">Show</button>' +
          '<button type="button" data-sec="' + esc(s.fieldKey) + '" data-vis="false" class="' + (st.isVisible ? '' : 'sel') + '">Hide</button>' +
        '</div>' +
        '<div class="seg wm-sec-en">' +
          '<button type="button" data-sec="' + esc(s.fieldKey) + '" data-en="true" class="' + (st.isEnable ? 'sel' : '') + '">Enabled</button>' +
          '<button type="button" data-sec="' + esc(s.fieldKey) + '" data-en="false" class="' + (st.isEnable ? '' : 'sel') + '">Disabled</button>' +
        '</div></div>';
    }).join(''));
  }

  $('#wmSecStepSel').on('change', function () {
    var id = $(this).val();
    if (id) loadStepSections(Number(id));
  });

  $(document).on('click', '.wm-sec-vis button', function () {
    var $btn = $(this);
    var st = secState[$btn.data('sec')] || (secState[$btn.data('sec')] = { isVisible: true, isEnable: true });
    st.isVisible = $btn.data('vis') === true;
    $btn.siblings('button').removeClass('sel');
    $btn.addClass('sel');
  });

  $(document).on('click', '.wm-sec-en button', function () {
    var $btn = $(this);
    var st = secState[$btn.data('sec')] || (secState[$btn.data('sec')] = { isVisible: true, isEnable: true });
    st.isEnable = $btn.data('en') === true;
    $btn.siblings('button').removeClass('sel');
    $btn.addClass('sel');
  });

  $('#wmSecSaveBtn').on('click', function () {
    if (!secStepId) { CMS.toast('Select a step first.', 'error'); return; }
    var payload = formSections.map(function (s, i) {
      var st = secState[s.fieldKey] || { isVisible: true, isEnable: true };
      return { sectionKey: s.fieldKey, isVisible: st.isVisible, isEnable: st.isEnable, displayOrder: i };
    });
    var $btn = $(this).prop('disabled', true);
    cmsAjax({
      url: '/api/workflows/steps/' + secStepId + '/sections', method: 'PUT',
      json: true, data: payload,
      fallbackMsg: 'Could not save sections.',
      success: function () { CMS.toast('Sections saved.', 'success'); loadSteps(); }
    }).always(function () { $btn.prop('disabled', false); });
  });

  /* ---------------- buttons tab ---------------- */
  function loadStepActions(stepId) {
    actStepId = stepId;
    cmsAjax({
      url: '/api/workflows/steps/' + stepId + '/actions', method: 'GET',
      fallbackMsg: 'Could not load buttons.',
      success: function (res) {
        actRows = (res || []).slice()
          .sort(function (a, b) { return (a.displayOrder || 0) - (b.displayOrder || 0); })
          .map(function (a) {
            return { actionCode: a.actionCode, actionTitle: a.actionTitle,
              nextStepCode: a.nextStepCode, nextRoleId: a.nextRoleID || null,
              saveOrMove: !!a.saveOrMove, isSendEmail: !!a.isSendEmail };
          });
        renderActList();
      }
    });
  }

  function actRowHtml(idx, row) {
    return '<div class="wm-act-row">' +
      '<input class="input wm-act-code" data-idx="' + idx + '" placeholder="Code (SUBMIT)" value="' + esc(row.actionCode) + '">' +
      '<input class="input wm-act-title" data-idx="' + idx + '" placeholder="Title (Submit)" value="' + esc(row.actionTitle) + '">' +
      '<select class="input wm-act-next" data-idx="' + idx + '">' +
        steps.map(function (s) {
          return '<option value="' + esc(s.stepCode) + '"' + (row.nextStepCode === s.stepCode ? ' selected' : '') + '>' +
            esc(s.stepTitle) + '</option>';
        }).join('') +
      '</select>' +
      '<select class="input wm-act-role" data-idx="' + idx + '">' +
        '<option value="">— No role —</option>' +
        roles.map(function (r) {
          return '<option value="' + r.roleId + '"' + (row.nextRoleId === r.roleId ? ' selected' : '') + '>' +
            esc(r.description) + '</option>';
        }).join('') +
      '</select>' +
      '<label class="chk"><input type="checkbox" class="wm-act-move" data-idx="' + idx + '"' + (row.saveOrMove ? ' checked' : '') + '> Save+Move</label>' +
      '<label class="chk"><input type="checkbox" class="wm-act-mail" data-idx="' + idx + '"' + (row.isSendEmail ? ' checked' : '') + '> Email</label>' +
      '<button type="button" class="btn btn-ghost btn-sm wm-act-del" data-idx="' + idx + '" title="Remove button">✕</button>' +
    '</div>';
  }

  function renderActList() {
    $('#wmActList').html(actRows.map(function (r, i) { return actRowHtml(i, r); }).join('') ||
      '<div class="hint">No buttons at this step — the form shows no action buttons here.</div>');
  }

  $('#wmActStepSel').on('change', function () {
    var id = $(this).val();
    if (id) loadStepActions(Number(id));
  });

  $('#wmActAddBtn').on('click', function () {
    actRows.push({ actionCode: '', actionTitle: '', nextStepCode: steps.length ? steps[0].stepCode : '',
      nextRoleId: null, saveOrMove: true, isSendEmail: false });
    renderActList();
  });

  $(document).on('click', '.wm-act-del', function () {
    actRows.splice(Number($(this).data('idx')), 1);
    renderActList();
  });

  // Typing in a row updates state without a rebuild, so focus stays.
  $(document).on('input change', '.wm-act-code, .wm-act-title, .wm-act-next, .wm-act-role, .wm-act-move, .wm-act-mail', function () {
    var $el = $(this);
    var row = actRows[Number($el.data('idx'))];
    if (!row) return;
    if ($el.hasClass('wm-act-code')) row.actionCode = $el.val();
    else if ($el.hasClass('wm-act-title')) row.actionTitle = $el.val();
    else if ($el.hasClass('wm-act-next')) row.nextStepCode = $el.val();
    else if ($el.hasClass('wm-act-role')) row.nextRoleId = $el.val() ? Number($el.val()) : null;
    else if ($el.hasClass('wm-act-move')) row.saveOrMove = $el.is(':checked');
    else if ($el.hasClass('wm-act-mail')) row.isSendEmail = $el.is(':checked');
  });

  $('#wmActSaveBtn').on('click', function () {
    if (!actStepId) { CMS.toast('Select a step first.', 'error'); return; }
    var bad = actRows.some(function (r) { return !$.trim(r.actionCode) || !$.trim(r.actionTitle) || !r.nextStepCode; });
    if (bad) { CMS.toast('Every button needs a code, a title and a next step.', 'error'); return; }
    var payload = actRows.map(function (r, i) {
      return { actionCode: $.trim(r.actionCode), actionTitle: $.trim(r.actionTitle),
        nextStepCode: r.nextStepCode, nextAssignmentType: 'Static',
        nextRoleId: r.nextRoleId, saveOrMove: r.saveOrMove,
        isSendEmail: r.isSendEmail, displayOrder: i };
    });
    var $btn = $(this).prop('disabled', true);
    cmsAjax({
      url: '/api/workflows/steps/' + actStepId + '/actions', method: 'PUT',
      json: true, data: payload,
      fallbackMsg: 'Could not save buttons.',
      success: function () { CMS.toast('Buttons saved.', 'success'); loadSteps(); }
    }).always(function () { $btn.prop('disabled', false); });
  });

  /* ---------------- boot ---------------- */
  cmsAjax({
    url: '/api/workflows/' + workflowId, method: 'GET',
    fallbackMsg: 'Could not load workflow.',
    success: function (w) {
      workflow = w;
      $('#wmTitle').text('Manage: ' + w.workflowName);
      $('#wmSub').text(w.formTitle + '  ·  ' + w.formKey + (w.workflowCode ? '  ·  ' + w.workflowCode : ''));
      loadFormSections();
      loadSteps();
    },
    error: function () {
      $('#wmTitle').text('Workflow not found.');
      return true;
    }
  });
  loadRoles();
  resetStepForm();
});
