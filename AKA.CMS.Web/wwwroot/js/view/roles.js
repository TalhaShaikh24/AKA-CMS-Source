/* Roles & Permissions — role list, permission catalog and grant/revoke
   toggles, all through the global cmsAjax helper. */
$(function () {
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
      url: '/Roles/List', method: 'GET',
      fallbackMsg: 'Could not load roles.',
      success: function (res) {
        roles = res || [];
        $('#roleCount').text(roles.length + ' roles');
        $('#roleList').html(roles.map(function (r) {
          return '<div class="role-item' + (r.roleId === selectedRoleId ? ' active' : '') + '" data-role="' + r.roleId + '">' +
            '<div><strong>' + esc(r.description) + '</strong>' +
            '<span class="hint">' + (r.isActive ? 'Active' : 'Inactive') + '</span></div>' +
            '<span class="hint"># ' + r.roleId + '</span></div>';
        }).join('') || '<p class="hint">No roles yet.</p>');
        if (selectId && roles.some(function (r) { return r.roleId === selectId; })) selectRole(selectId);
        else if (!selectedRoleId && roles.length) selectRole(roles[0].roleId);
      }
    });
  }

  function loadCatalog() {
    cmsAjax({
      url: '/Roles/Catalog', method: 'GET',
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
      url: '/Roles/Permissions/' + id, method: 'GET',
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

  $(document).on('click', '.role-item', function () { selectRole(Number($(this).data('role'))); });

  $(document).on('change', '[data-perm]', function () {
    var pid = Number($(this).data('perm'));
    var grant = $(this).is(':checked');
    var $box = $(this);
    if (grant) {
      cmsAjax({
        url: '/Roles/AssignPermission/' + selectedRoleId, method: 'POST', json: true,
        data: { controllerActionId: pid },
        fallbackMsg: 'Could not grant permission.',
        success: function () { assigned[pid] = true; CMS.toast('Permission granted.', 'success'); },
        error: function () { $box.prop('checked', false); return false; }
      });
    } else {
      cmsAjax({
        url: '/Roles/RemovePermission/' + selectedRoleId + '?controllerActionId=' + pid, method: 'DELETE',
        fallbackMsg: 'Could not revoke permission.',
        success: function () { delete assigned[pid]; CMS.toast('Permission revoked.', 'success'); },
        error: function () { $box.prop('checked', true); return false; }
      });
    }
  });

  $('#addRoleBtn').on('click', function () {
    $('#roleForm')[0].reset();
    $('#roleModalNew').addClass('open');
  });

  $('#roleForm').cmsValidate({
    onValid: function () {
      cmsAjax({
        url: '/Roles/Create', method: 'POST', json: true,
        data: { description: $.trim($('#nrDesc').val()) },
        fallbackMsg: 'Could not create role.',
        success: function (res) {
          $('#roleModalNew').removeClass('open');
          CMS.toast('Role created.', 'success');
          loadRoles(res && res.roleId);
        }
      });
    }
  });

  loadRoles();
  loadCatalog();
});
