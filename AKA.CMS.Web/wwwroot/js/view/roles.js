/* Roles & Permissions — role list, permission catalog and grant/revoke
   toggles, DIRECTLY from the Web API through the global cmsAjax helper. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);
  CMS.initValidation(document);

  var roles = [];
  var catalog = [];
  var selectedRoleId = null;
  var assigned = {};

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  function loadRoles(selectId) {
    cmsAjax({
      url: '/api/roles', method: 'GET',
      fallbackMsg: 'Could not load roles.',
      success: function (res) {
        roles = res || [];
        $('#roleCount').text(roles.length + ' roles');
        $('#roleList').html(roles.map(function (r) {
          return '<div class="role-item' + (r.roleId === selectedRoleId ? ' active' : '') + '" data-role="' + r.roleId + '">' +
            '<div><strong>' + esc(r.description) + '</strong>' +
            '<span class="hint">' + (r.isActive ? 'Active' : 'Inactive') + '</span></div>' +
            '<div style="display:flex;align-items:center;gap:8px">' +
            '<span class="hint"># ' + r.roleId + '</span>' +
            '<button class="btn btn-ghost btn-sm" data-edit-role="' + r.roleId + '" type="button" data-permission="Roles:Write">Edit</button>' +
            '</div></div>';
        }).join('') || '<p class="hint">No roles yet.</p>');
        if (selectId && roles.some(function (r) { return r.roleId === selectId; })) selectRole(selectId);
        else if (!selectedRoleId && roles.length) selectRole(roles[0].roleId);
      }
    });
  }

  function loadCatalog() {
    cmsAjax({
      url: '/api/permissions', method: 'GET',
      error: function () { return true; },
      success: function (res) { catalog = res || []; renderPerms(); }
    });
  }

  function selectRole(id) {
    selectedRoleId = id;
    $('#roleList .role-item').removeClass('active');
    $('#roleList .role-item[data-role="' + id + '"]').addClass('active');
    var r = roles.filter(function (x) { return x.roleId === id; })[0];
    $('#permTitle').text('Permissions — ' + (r ? r.description : ''));
    cmsAjax({
      url: '/api/roles/' + id + '/permissions', method: 'GET',
      fallbackMsg: 'Could not load role permissions.',
      success: function (res) {
        assigned = {};
        (res || []).forEach(function (p) { assigned[p.id] = true; });
        renderPerms();
      }
    });
  }

  function renderPerms() {
    if (!selectedRoleId) return;
    var groups = {};
    catalog.forEach(function (p) {
      (groups[p.controllerName] = groups[p.controllerName] || []).push(p);
    });
    var html = Object.keys(groups).sort().map(function (g) {
      var rows = groups[g].map(function (p) {
        var on = !!assigned[p.id];
        return '<div class="perm-row"><span class="pa">' + esc(g) + ' : ' + esc(p.action) + '</span>' +
          '<label class="switch"><input type="checkbox" data-perm="' + p.id + '"' + (on ? ' checked' : '') + '><span class="slider"></span></label></div>';
      }).join('');
      return '<div class="perm-group"><h4>' + esc(g) + '</h4>' + rows + '</div>';
    }).join('');
    $('#permBody').html(html || '<p class="hint">No permissions in catalog.</p>');
  }

  $(document).on('click', '.role-item', function (e) {
    if ($(e.target).closest('[data-edit-role]').length) return;
    selectRole(Number($(this).data('role')));
  });

  var editingRoleId = null;
  $(document).on('click', '[data-edit-role]', function (e) {
    e.stopPropagation();
    var id = Number($(this).data('edit-role'));
    var r = roles.filter(function (x) { return x.roleId === id; })[0];
    if (!r) return;
    editingRoleId = id;
    $('#roleModalTitle').text('Edit Role');
    $('#nrDesc').val(r.description);
    $('#roleFormSubmit').text('Save Changes');
    $('#roleModalNew').addClass('open');
  });

  $(document).on('change', '[data-perm]', function () {
    var pid = Number($(this).data('perm'));
    var grant = $(this).is(':checked');
    var $box = $(this);
    if (grant) {
      cmsAjax({
        url: '/api/roles/' + selectedRoleId + '/permissions', method: 'POST', json: true,
        data: { controllerActionId: pid },
        fallbackMsg: 'Could not grant permission.',
        success: function () { assigned[pid] = true; CMS.toast('Permission granted.', 'success'); },
        error: function () { $box.prop('checked', false); return false; }
      });
    } else {
      cmsAjax({
        url: '/api/roles/' + selectedRoleId + '/permissions/' + pid, method: 'DELETE',
        fallbackMsg: 'Could not revoke permission.',
        success: function () { delete assigned[pid]; CMS.toast('Permission revoked.', 'success'); },
        error: function () { $box.prop('checked', true); return false; }
      });
    }
  });

  $('#addRoleBtn').on('click', function () {
    editingRoleId = null;
    $('#roleModalTitle').text('New Role');
    $('#roleForm')[0].reset();
    $('#roleFormSubmit').text('Create Role');
    $('#roleModalNew').addClass('open');
  });

  $('#roleForm').cmsValidate({
    onValid: function () {
      var desc = $.trim($('#nrDesc').val());
      if (editingRoleId) {
        cmsAjax({
          url: '/api/roles/' + editingRoleId, method: 'PUT', json: true,
          data: { description: desc },
          fallbackMsg: 'Could not update role.',
          success: function () {
            $('#roleModalNew').removeClass('open');
            CMS.toast('Role updated.', 'success');
            editingRoleId = null;
            loadRoles(selectedRoleId);
          }
        });
      } else {
        cmsAjax({
          url: '/api/roles', method: 'POST', json: true,
          data: { description: desc },
          fallbackMsg: 'Could not create role.',
          success: function (res) {
            $('#roleModalNew').removeClass('open');
            CMS.toast('Role created.', 'success');
            loadRoles(res && res.roleId);
          }
        });
      }
    }
  });

  loadRoles();
  loadCatalog();
});
