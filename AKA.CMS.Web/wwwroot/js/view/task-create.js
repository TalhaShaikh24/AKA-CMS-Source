/* Create Task — 3-step wizard (Figma: Task Details → Assign To →
   Review & Create). Posts to /api/tasks DIRECTLY via cmsAjax. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);
  CMS.initValidation(document);

  var caseCache = {};

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

  function goStep(n) {
    $('[data-pane]').prop('hidden', true);
    $('[data-pane="' + n + '"]').prop('hidden', false);
    $('#taskSteps .step').each(function () {
      var s = +$(this).data('step');
      $(this).toggleClass('done', s < n).toggleClass('current', s === n);
      $(this).find('.circle').text(s < n ? '✓' : s);
    });
    window.scrollTo(0, 0);
  }

  /* ---------- case picker ---------- */
  var $case = $('#tCase');
  $case.select2({
    placeholder: 'Search case by number, patient name, or MR…',
    minimumInputLength: 0, width: '100%',
    ajax: {
      transport: function (params, success, failure) {
        cmsAjax({
          url: '/api/cases', method: 'GET',
          data: { search: params.data.term || '', page: params.data.page || 1, pageSize: 20 },
          fallbackMsg: 'Could not load cases.', success: success,
          error: function (xhr) { failure(xhr); }
        });
      },
      processResults: function (res, params) {
        params.page = params.page || 1;
        var items = (res && res.items) || [];
        items.forEach(function (c) { caseCache[c.caseId] = c; });
        return {
          results: items.map(function (c) {
            return {
              id: c.caseId,
              text: (c.caseNumber || ('#' + c.caseId)) + ' · ' +
                    (c.memberName || 'Unknown patient') +
                    (c.memberMrNo ? ' (' + c.memberMrNo + ')' : '')
            };
          }),
          pagination: { more: (params.page * 20) < ((res && res.totalCount) || 0) }
        };
      }
    }
  });

  /* ---------- roles + users ---------- */
  cmsAjax({
    url: '/api/roles', method: 'GET', fallbackMsg: 'Could not load roles.',
    success: function (res) {
      (res || []).forEach(function (r) {
        if (r.isActive !== false) $('#tRole').append(new Option(r.description || ('Role ' + r.roleId), r.roleId));
      });
    }
  });
  cmsAjax({
    url: '/api/users', method: 'GET', fallbackMsg: 'Could not load users.',
    success: function (res) {
      (res || []).forEach(function (u) {
        if (u.isActive !== false) $('#tUser').append(new Option(u.username + (u.email ? ' (' + u.email + ')' : ''), u.userId));
      });
    }
  });

  function markInvalid($el, msg) {
    $el.closest('.field').addClass('invalid').find('.field-error').text(msg || 'This field is required');
  }
  function clearInvalid() { $('.field').removeClass('invalid'); $('.field-error').text(''); }

  /* ---------- step navigation ---------- */
  $('#toStep2').on('click', function () {
    clearInvalid();
    var ok = true;
    if (!$.trim($('#tTitle').val())) { markInvalid($('#tTitle')); ok = false; }
    if (!$case.val()) { markInvalid($case); ok = false; }
    if (!$('#tDue').val()) { markInvalid($('#tDue')); ok = false; }
    if (ok) goStep(2);
  });
  $('#backTo1').on('click', function () { goStep(1); });
  $('#backTo2').on('click', function () { goStep(2); });

  $('#toStep3').on('click', function () {
    clearInvalid();
    if (!$('#tRole').val() && !$('#tUser').val()) {
      markInvalid($('#tUser'), 'Assign to a role, a user, or both.');
      return;
    }
    buildReview();
    goStep(3);
  });

  function notifyList() {
    var n = [];
    if ($('#nHc').is(':checked')) n.push('Notify Helpline Coordinator');
    if ($('#nCc').is(':checked')) n.push('Notify Clinical Coordinator');
    if ($('#nPc').is(':checked')) n.push('Notify Programme Coordinator');
    return n;
  }

  function buildReview() {
    var c = caseCache[$case.val()] || {};
    var rows = [
      ['Title', $.trim($('#tTitle').val())],
      ['Patient', (c.caseNumber || '') + ' · ' + (c.memberName || '')],
      ['Type', $('#tType').val()],
      ['Priority', $('#tPriority').val()],
      ['Due', $('#tDue').val()],
      ['Role', $('#tRole option:selected').text()],
      ['User', $('#tUser option:selected').text()],
      ['Recipients', notifyList().join(', ') || '—']
    ];
    var html = '';
    rows.forEach(function (r) {
      html += '<div class="k">' + esc(r[0]) + '</div><div class="v">' + esc(r[1]) + '</div>';
    });
    var desc = $.trim($('#tDesc').val());
    if (desc) html += '<div class="k">Description</div><div class="v">' + esc(desc) + '</div>';
    $('#reviewBox').html(html);
  }

  /* ---------- create ---------- */
  $('#createTaskBtn').on('click', function () {
    var payload = {
      title: $.trim($('#tTitle').val()),
      description: $.trim($('#tDesc').val()) || null,
      caseId: +$case.val(),
      taskType: $('#tType').val() || null,
      priority: $('#tPriority').val(),
      dueDate: $('#tDue').val(),
      assignedToRoleId: $('#tRole').val() ? +$('#tRole').val() : null,
      assignedToUserId: $('#tUser').val() ? +$('#tUser').val() : null,
      notifyRecipients: notifyList().join('; ') || null
    };
    var $btn = $(this).prop('disabled', true);
    cmsAjax({
      url: '/api/tasks', method: 'POST',
      data: JSON.stringify(payload),
      fallbackMsg: 'Could not create the task.',
      success: function (res) {
        $('#successMsg').text('The task "' + (res.title || '') + '" has been assigned' +
          (res.assignedUserName ? ' to ' + res.assignedUserName : '') + '.');
        $('#successTaskId').text(res.taskNumber ? 'Task ID: ' + res.taskNumber : '');
        goStep(4);
      },
      complete: function () { $btn.prop('disabled', false); }
    });
  });
});
