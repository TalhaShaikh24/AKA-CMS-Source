/* Workflow Roles — the workflow-role list and which users hold each
   one, via /api/workflow-roles. A workflow role is separate from a
   user role: it says who a workflow step waits on. Assigning one to
   a user is optional — a user with no workflow roles is unaffected. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);

  var roles = [];
  var allUsers = [];

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  function load() {
    cmsAjax({
      url: '/api/workflow-roles', method: 'GET',
      fallbackMsg: 'Could not load workflow roles.',
      success: function (res) {
        roles = res || [];
        $('#wrCount').text(roles.length + ' role' + (roles.length === 1 ? '' : 's'));
        $('#wrTbody').html(roles.map(function (r) {
          return '<tr>' +
            '<td><code>' + esc(r.workflowRoleCode) + '</code></td>' +
            '<td><strong>' + esc(r.title) + '</strong></td>' +
            '<td>' + esc(r.description || '—') + '</td>' +
            '<td>' + r.userCount + '</td>' +
            '<td>' + (r.isActive
              ? '<span class="pill" style="background:#e6f4ea;color:#1e7e34">Active</span>'
              : '<span class="pill">Inactive</span>') + '</td>' +
            '<td class="row-actions" style="white-space:nowrap">' +
              '<button class="btn btn-ghost btn-sm" data-users="' + r.workflowRoleId + '" type="button">Users</button> ' +
              '<button class="btn btn-ghost btn-sm" data-edit="' + r.workflowRoleId + '" type="button" data-permission="WorkflowRoles:Write">Edit</button> ' +
              '<button class="btn btn-ghost btn-sm" data-del="' + r.workflowRoleId + '" type="button" data-permission="WorkflowRoles:Write">Delete</button>' +
            '</td></tr>';
        }).join('') || '<tr><td colspan="6" class="hint">No workflow roles yet — add one above.</td></tr>');
        CMS.bindLayout();
      }
    });
  }

  function loadUsers(onDone) {
    cmsAjax({
      url: '/api/workflow-roles/users', method: 'GET',
      fallbackMsg: 'Could not load users.',
      success: function (res) {
        allUsers = (res || []).filter(function (u) { return u.isActive !== false; });
        if (typeof onDone === 'function') onDone();
      }
    });
  }

  /* ---------------- create / edit ---------------- */
  $('#wrNewBtn').on('click', function () {
    $('#wrModalTitle').text('New Role');
    $('#wrForm')[0].reset();
    $('#wrRoleId').val('');
    $('#fWrCode, #fWrTitle').removeClass('invalid');
    $('#wrModal').addClass('open');
    $('#wrCode').focus();
  });

  $(document).on('click', '[data-edit]', function () {
    var id = Number($(this).data('edit'));
    var r = roles.filter(function (x) { return x.workflowRoleId === id; })[0];
    if (!r) return;
    $('#wrModalTitle').text('Edit Role');
    $('#wrRoleId').val(r.workflowRoleId);
    $('#wrCode').val(r.workflowRoleCode);
    $('#wrTitle').val(r.title);
    $('#wrDesc').val(r.description || '');
    $('#fWrCode, #fWrTitle').removeClass('invalid');
    $('#wrModal').addClass('open');
  });

  $('#wrForm').on('submit', function (e) {
    e.preventDefault();
    var code = $.trim($('#wrCode').val());
    var title = $.trim($('#wrTitle').val());
    var ok = true;
    if (!code) { $('#fWrCode').addClass('invalid'); ok = false; }
    if (!title) { $('#fWrTitle').addClass('invalid'); ok = false; }
    if (!ok) { CMS.toast('Please fill in the required fields.', 'error'); return; }
    var id = $('#wrRoleId').val();
    var $btn = $('#wrSaveBtn').prop('disabled', true);
    cmsAjax({
      url: id ? '/api/workflow-roles/' + id : '/api/workflow-roles',
      method: id ? 'PUT' : 'POST',
      json: true,
      data: { workflowRoleCode: code, title: title, description: $.trim($('#wrDesc').val()) || null },
      fallbackMsg: 'Could not save role.',
      success: function () {
        CMS.toast(id ? 'Role updated.' : 'Role created.', 'success');
        $('#wrModal').removeClass('open');
        load();
      }
    }).always(function () { $btn.prop('disabled', false); });
  });

  $('#wrCode').on('input', function () { $('#fWrCode').removeClass('invalid'); });
  $('#wrTitle').on('input', function () { $('#fWrTitle').removeClass('invalid'); });

  /* ---------------- delete (soft: deactivate) ---------------- */
  $(document).on('click', '[data-del]', function () {
    var id = Number($(this).data('del'));
    if (!window.confirm('Delete this workflow role? Steps using it keep working on their user role.')) return;
    cmsAjax({
      url: '/api/workflow-roles/' + id, method: 'DELETE',
      fallbackMsg: 'Could not delete role.',
      success: function () { CMS.toast('Role deleted.', 'success'); load(); }
    });
  });

  /* ---------------- users holding a role ---------------- */
  $(document).on('click', '[data-users]', function () {
    var id = Number($(this).data('users'));
    var r = roles.filter(function (x) { return x.workflowRoleId === id; })[0];
    if (!r) return;
    $('#wrUsersTitle').text('Users — ' + r.title);
    $('#wrUsersRoleId').val(id);
    $('#wrUsersSelect').html(allUsers.map(function (u) {
      return '<option value="' + u.userId + '">' + esc(u.username) + (u.email ? ' (' + esc(u.email) + ')' : '') + '</option>';
    }).join(''));
    $('#wrUsersModal').addClass('open');
    cmsAjax({
      url: '/api/workflow-roles/' + id + '/users', method: 'GET',
      fallbackMsg: 'Could not load assigned users.',
      success: function (res) {
        $('#wrUsersSelect').val((res || []).map(function (u) { return String(u.userId); })).trigger('change');
      }
    });
  });

  $('#wrUsersSaveBtn').on('click', function () {
    var id = $('#wrUsersRoleId').val();
    var userIds = ($('#wrUsersSelect').val() || []).map(function (v) { return Number(v); });
    var $btn = $(this).prop('disabled', true);
    cmsAjax({
      url: '/api/workflow-roles/' + id + '/users', method: 'PUT',
      json: true, data: { userIds: userIds },
      fallbackMsg: 'Could not save users.',
      success: function () {
        CMS.toast('Users saved.', 'success');
        $('#wrUsersModal').removeClass('open');
        load();
      }
    }).always(function () { $btn.prop('disabled', false); });
  });

  loadUsers();
  load();
});
