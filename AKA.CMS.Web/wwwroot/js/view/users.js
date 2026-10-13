/* Users — loads team members through the global cmsAjax helper,
   DIRECTLY from the Web API. Razor never touches the backend. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);
  CMS.initValidation(document);

  var allUsers = [];
  var allRoles = [];
  var filterState = { q: '', status: '' };

  /* ---------- filters ---------- */
  $('#userFilters').cmsFilters({
    filters: [
      { key: 'q', label: 'Search', type: 'search', placeholder: 'Username or email…' },
      { key: 'status', label: 'Status', type: 'select', options: ['Active', 'Inactive', 'Locked'] }
    ]
  });
  $('#filterToggle').on('click', function () {
    var open = $('#userFilterPanel').prop('hidden');
    $('#userFilterPanel').prop('hidden', !open);
    $(this).attr('aria-expanded', open);
  });
  $('#userApplyFilters').on('click', function () {
    var v = $('#userFilters').data('cmsfilters').getValues();
    filterState = { q: v.q || '', status: v.status || '' };
    var n = (filterState.q ? 1 : 0) + (filterState.status ? 1 : 0);
    $('#filterCount').prop('hidden', !n).text(n);
    render();
  });
  $('#userClearFilters').on('click', function () {
    $('#userFilters').data('cmsfilters').reset();
    filterState = { q: '', status: '' };
    $('#filterCount').prop('hidden', true);
    render();
  });

  /* ---------- load ---------- */
  function load() {
    cmsAjax({
      url: '/api/users', method: 'GET',
      fallbackMsg: 'Could not load users.',
      success: function (res) { allUsers = res || []; render(); }
    });
    cmsAjax({
      url: '/api/roles', method: 'GET',
      error: function () { return true; },
      success: function (res) {
        allRoles = (res || []).filter(function (r) { return r.isActive; });
        var opts = allRoles.map(function (r) {
          return '<option value="' + r.roleId + '">' + esc(r.description) + '</option>';
        }).join('');
        $('#nuRoles').html(opts);
        $('#assignRoleSel').html(opts);
      }
    });
  }

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  function statusOf(u) {
    if (u.isLocked) return '<span class="st-locked">Locked</span>';
    return u.isActive ? '<span class="st-active">Active</span>' : '<span class="st-inactive">Inactive</span>';
  }

  function render() {
    var q = filterState.q.toLowerCase();
    var rows = allUsers.filter(function (u) {
      if (q && (u.username || '').toLowerCase().indexOf(q) < 0 &&
          (u.email || '').toLowerCase().indexOf(q) < 0) return false;
      if (filterState.status === 'Active' && (!u.isActive || u.isLocked)) return false;
      if (filterState.status === 'Inactive' && u.isActive) return false;
      if (filterState.status === 'Locked' && !u.isLocked) return false;
      return true;
    });
    $('#userCount').text(rows.length + ' user' + (rows.length === 1 ? '' : 's'));
    $('#userTbody').html(rows.map(function (u) {
      var initials = esc((u.username || '?').substring(0, 2).toUpperCase());
      var pills = (u.roles || []).map(function (r) { return '<span class="pill">' + esc(r) + '</span>'; }).join('') || '<span class="hint">—</span>';
      return '<tr>' +
        '<td><div class="u-cell"><div class="avatar">' + initials + '</div>' +
        '<div><strong>' + esc(u.username) + '</strong><br><span class="hint">' + esc(u.email || '—') + '</span></div></div></td>' +
        '<td>' + pills + '</td>' +
        '<td>' + statusOf(u) + '</td>' +
        '<td class="row-actions">' +
        '<button class="btn btn-ghost btn-sm" data-edit="' + u.userId + '" type="button">Edit</button>' +
        '<button class="btn btn-ghost btn-sm" data-roles="' + u.userId + '" type="button">Roles</button>' +
        '</td></tr>';
    }).join('') || '<tr><td colspan="4" class="hint">No users found.</td></tr>');

    $('#kpiTotal').text(allUsers.length);
    $('#kpiActive').text(allUsers.filter(function (u) { return u.isActive && !u.isLocked; }).length);
    $('#kpiLocked').text(allUsers.filter(function (u) { return u.isLocked; }).length);
    $('#kpiAdmins').text(allUsers.filter(function (u) { return u.isAdmin; }).length);
  }

  /* ---------- add / edit ---------- */
  $('#addUserBtn').on('click', function () {
    $('#userModalTitle').text('Add User');
    $('#userFormSubmit').text('Add User');
    $('#userForm')[0].reset();
    $('#editUserId').val('');
    $('#nuUsername').prop('disabled', false);
    $('#nuRoles').val(null).trigger('change');
    $('#fUsername, #fPassword, #fRoles').show();
    $('#fStatusRow, #fNewPass').hide();
    $('#nuUsername, #nuPassword').attr('required', 'required');
    $('#userModal').addClass('open');
  });

  function loadUserRoles(userId) {
    var u = allUsers.filter(function (x) { return x.userId == userId; })[0];
    if (!u) return;
    // Map role names to IDs using allRoles
    var roleNames = u.roles || [];
    var roleIds = allRoles.filter(function (r) {
      return roleNames.indexOf(r.description) >= 0 || roleNames.indexOf(r.roleName) >= 0;
    }).map(function (r) { return String(r.roleId); });
    $('#nuRoles').val(roleIds).trigger('change');
  }

  $(document).on('click', '[data-edit]', function () {
    var u = allUsers.filter(function (x) { return x.userId == $(this).data('edit'); }.bind(this))[0];
    if (!u) return;
    $('#userModalTitle').text('Edit — ' + u.username);
    $('#userFormSubmit').text('Save Changes');
    $('#editUserId').val(u.userId);
    $('#nuUsername').val(u.username).prop('disabled', true);
    $('#nuEmail').val(u.email || '');
    $('#euActive').prop('checked', !!u.isActive);
    $('#euLocked').prop('checked', !!u.isLocked);
    $('#euNewPass').val('');
    // Show username (read-only) and roles on edit; hide password.
    $('#fUsername').show();
    $('#fPassword').hide();
    $('#fRoles').show();
    $('#fStatusRow, #fNewPass').show();
    $('#nuUsername').removeAttr('required');
    $('#nuPassword').removeAttr('required');
    // Load user's current roles
    loadUserRoles(u.userId);
    $('#userModal').addClass('open');
  });

  function syncUserRoles(userId, newRoleIds, done) {
    var u = allUsers.filter(function (x) { return x.userId == userId; })[0];
    var oldRoleIds = [];
    if (u) {
      var roleNames = u.roles || [];
      oldRoleIds = allRoles.filter(function (r) {
        return roleNames.indexOf(r.description) >= 0 || roleNames.indexOf(r.roleName) >= 0;
      }).map(function (r) { return r.roleId; });
    }
    var toAdd = newRoleIds.filter(function (id) { return oldRoleIds.indexOf(id) < 0; });
    var toRemove = oldRoleIds.filter(function (id) { return newRoleIds.indexOf(id) < 0; });
    var queue = [];
    toAdd.forEach(function (rid) { queue.push({ method: 'POST', url: '/api/users/' + userId + '/roles', data: { roleId: rid } }); });
    toRemove.forEach(function (rid) { queue.push({ method: 'DELETE', url: '/api/users/' + userId + '/roles/' + rid }); });
    (function next() {
      var q = queue.shift();
      if (!q) { done(); return; }
      cmsAjax({
        url: q.url, method: q.method, json: true, data: q.data,
        fallbackMsg: 'Could not update user roles.',
        success: next, error: next
      });
    })();
  }

  $('#userForm').cmsValidate({
    onValid: function () {
      var id = $('#editUserId').val();
      if (id) {
        var newRoleIds = ($('#nuRoles').val() || []).map(Number);
        cmsAjax({
          url: '/api/users/' + id, method: 'PUT', json: true,
          data: {
            email: $.trim($('#nuEmail').val()) || null,
            isActive: $('#euActive').is(':checked'),
            isLocked: $('#euLocked').is(':checked'),
            newPassword: $('#euNewPass').val() || null
          },
          fallbackMsg: 'Could not update user.',
          success: function () {
            syncUserRoles(id, newRoleIds, function () {
              $('#userModal').removeClass('open');
              CMS.toast('User updated.', 'success');
              load();
            });
          }
        });
      } else {
        var roleIds = ($('#nuRoles').val() || []).map(Number);
        if (!roleIds.length) {
          $('#fRoles').addClass('invalid');
          $('#fRoles .field-error').text('Please select at least one role.').show();
          CMS.toast('Please select at least one role.', 'error');
          return;
        }
        cmsAjax({
          url: '/api/users', method: 'POST', json: true,
          data: {
            username: $.trim($('#nuUsername').val()),
            password: $('#nuPassword').val(),
            email: $.trim($('#nuEmail').val()) || null,
            roleIds: roleIds
          },
          fallbackMsg: 'Could not create user.',
          success: function () {
            $('#userModal').removeClass('open');
            CMS.toast('User created.', 'success');
            load();
          }
        });
      }
    }
  });

  /* ---------- roles modal ---------- */
  var roleUserId = null;
  $(document).on('click', '[data-roles]', function () {
    roleUserId = $(this).data('roles');
    var u = allUsers.filter(function (x) { return x.userId == roleUserId; })[0];
    $('#roleModalUser').text(u ? u.username : '');
    renderRoleList(u);
    $('#roleModal').addClass('open');
  });

  function renderRoleList(u) {
    var assigned = u ? (u.roles || []) : [];
    $('#roleList').html(assigned.length ? assigned.map(function (r) {
      var role = allRoles.filter(function (x) { return x.description === r; })[0];
      var rid = role ? role.roleId : 0;
      return '<div class="pill" style="font-size:13px">' + esc(r) +
        ' <a href="#" data-unassign="' + rid + '" style="margin-left:6px;color:#c0392b">✕</a></div>';
    }).join(' ') : '<span class="hint">No roles assigned.</span>');
  }

  $('#assignRoleBtn').on('click', function () {
    var rid = Number($('#assignRoleSel').val());
    if (!rid || !roleUserId) { CMS.toast('Choose a role first.', 'error'); return; }
    cmsAjax({
      url: '/api/users/' + roleUserId + '/roles', method: 'POST', json: true,
      data: { roleId: rid, unitCode: 0 },
      fallbackMsg: 'Could not assign role.',
      success: function () { CMS.toast('Role assigned.', 'success'); load(); $('#roleModal').removeClass('open'); }
    });
  });

  $(document).on('click', '[data-unassign]', function (e) {
    e.preventDefault();
    var rid = $(this).data('unassign');
    if (!rid || !roleUserId) return;
    cmsAjax({
      url: '/api/users/' + roleUserId + '/roles/' + rid, method: 'DELETE',
      fallbackMsg: 'Could not remove role.',
      success: function () { CMS.toast('Role removed.', 'success'); load(); $('#roleModal').removeClass('open'); }
    });
  });

  load();
});
