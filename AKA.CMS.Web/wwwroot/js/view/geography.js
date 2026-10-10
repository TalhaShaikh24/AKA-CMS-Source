/* Geography — regions / local councils / villages master data.
   Loaded through the global cmsAjax helper DIRECTLY from the Web API.
   Razor never touches the backend. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);
  CMS.initValidation(document);

  var activeTab = 'regions';
  var regions = [], councils = [], villages = [];
  var editing = null; // {kind, id, rowVersion}

  var META = {
    regions:  { title: 'Region',         listUrl: '/api/geography/regions',  parentLabel: null,           parentKey: null,        nameKey: 'regionName',  idKey: 'regionId'  },
    councils: { title: 'Local Council',  listUrl: '/api/geography/councils', parentLabel: 'Region',       parentKey: 'regionId',  nameKey: 'councilName', idKey: 'councilId' },
    villages: { title: 'Village',        listUrl: '/api/geography/villages', parentLabel: 'Local Council',parentKey: 'councilId', nameKey: 'villageName', idKey: 'villageId' }
  };

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

  /* ---------- tabs ---------- */
  $('#geoTabs .tab').on('click', function () {
    activeTab = $(this).data('tab');
    $('#geoTabs .tab').removeClass('active');
    $(this).addClass('active');
    $('.tab-panel').removeClass('active');
    $('#panel-' + activeTab).addClass('active');
    $('#addGeoBtn').text('+ Add ' + META[activeTab].title);
  });

  /* ---------- load ---------- */
  function loadAll() {
    cmsAjax({ url: '/api/geography/regions?includeInactive=true', method: 'GET',
      fallbackMsg: 'Could not load regions.',
      success: function (res) { regions = res || []; renderRegions(); fillParentOptions(); } });
    cmsAjax({ url: '/api/geography/councils?includeInactive=true', method: 'GET',
      fallbackMsg: 'Could not load local councils.',
      success: function (res) { councils = res || []; renderCouncils(); } });
    cmsAjax({ url: '/api/geography/villages?includeInactive=true', method: 'GET',
      fallbackMsg: 'Could not load villages.',
      success: function (res) { villages = res || []; renderVillages(); } });
  }

  function statusCell(active) {
    return '<td class="' + (active ? 'st-active' : 'st-inactive') + '">' + (active ? 'Active' : 'Inactive') + '</td>';
  }
  function editBtn(kind, id) {
    return '<td class="row-actions" data-permission="Geography:Write">' +
      '<button class="btn btn-ghost btn-sm" data-kind="' + kind + '" data-edit="' + id + '">Edit</button></td>';
  }

  function renderRegions() {
    var html = regions.map(function (r) {
      return '<tr><td><strong>' + esc(r.regionName) + '</strong></td>' + statusCell(r.isActive) + editBtn('regions', r.regionId) + '</tr>';
    }).join('');
    $('#regionRows').html(html || '<tr><td colspan="3" class="hint">No regions found.</td></tr>');
    if (window.CMS && typeof CMS.applyPermissions === 'function') CMS.applyPermissions(document);
  }
  function renderCouncils() {
    var html = councils.map(function (c) {
      return '<tr><td><strong>' + esc(c.councilName) + '</strong></td><td>' + esc(c.regionName || '—') + '</td>' +
        statusCell(c.isActive) + editBtn('councils', c.councilId) + '</tr>';
    }).join('');
    $('#councilRows').html(html || '<tr><td colspan="4" class="hint">No local councils found.</td></tr>');
    if (window.CMS && typeof CMS.applyPermissions === 'function') CMS.applyPermissions(document);
  }
  function renderVillages() {
    var html = villages.map(function (v) {
      return '<tr><td><strong>' + esc(v.villageName) + '</strong></td><td>' + esc(v.councilName || '—') + '</td>' +
        statusCell(v.isActive) + editBtn('villages', v.villageId) + '</tr>';
    }).join('');
    $('#villageRows').html(html || '<tr><td colspan="4" class="hint">No villages found.</td></tr>');
    if (window.CMS && typeof CMS.applyPermissions === 'function') CMS.applyPermissions(document);
  }

  function fillParentOptions() {
    // Parent dropdown depends on which tab's modal is open; filled in openModal.
  }

  /* ---------- modal ---------- */
  function openModal(kind, item) {
    var meta = META[kind];
    editing = item ? { kind: kind, id: item[meta.idKey], rowVersion: item.rowVersion } : { kind: kind, id: 0, rowVersion: null };
    $('#geoModalTitle').text((item ? 'Edit ' : 'Add ') + meta.title);
    $('#fNameLabel').html(meta.title + ' Name <span class="req">*</span>');
    $('#fName').val(item ? item[meta.nameKey] : '');
    $('#fActiveWrap').toggle(!!item);
    $('#fActive').val(item ? String(!!item.isActive) : 'true');

    var $pw = $('#fParentWrap'), $p = $('#fParent');
    if (meta.parentLabel) {
      $pw.show();
      $('#fParentLabel').text(meta.parentLabel);
      var opts = kind === 'councils' ? regions : councils;
      var valKey = meta.parentKey;
      var html = '<option value="">— None —</option>' + opts.filter(function (o) { return o.isActive; }).map(function (o) {
        var ok = kind === 'councils' ? o.regionId : o.councilId;
        var on = kind === 'councils' ? o.regionName : o.councilName;
        return '<option value="' + ok + '">' + esc(on) + '</option>';
      }).join('');
      $p.html(html);
      $p.val(item && item[valKey] ? String(item[valKey]) : '').trigger('change');
    } else {
      $pw.hide();
      $p.html('');
    }
    $('#geoForm').find('.field').removeClass('invalid');
    $('#geoForm').find('.field-error').text('');
    $('#geoModal').addClass('open');
  }
  function closeModal() { $('#geoModal').removeClass('open'); }

  $('#addGeoBtn').on('click', function () { openModal(activeTab, null); });

  $(document).on('click', '[data-edit]', function () {
    var kind = $(this).data('kind'), id = $(this).data('edit'), meta = META[kind];
    var list = kind === 'regions' ? regions : kind === 'councils' ? councils : villages;
    var item = list.filter(function (x) { return x[meta.idKey] == id; })[0];
    if (item) openModal(kind, item);
  });

  $('#geoFormSubmit').on('click', function () { $('#geoForm').submit(); });

  $('#geoForm').cmsValidate({
    onValid: function () {
      var kind = editing.kind, meta = META[kind];
      var payload = {};
      payload[meta.nameKey] = $('#fName').val().trim();
      if (meta.parentKey) {
        var pv = $('#fParent').val();
        payload[meta.parentKey] = pv ? parseInt(pv, 10) : null;
      }
      var isNew = !editing.id;
      if (!isNew) {
        payload.isActive = $('#fActive').val() === 'true';
        payload.rowVersion = editing.rowVersion;
      }
      var base = '/api/geography/' + (kind === 'regions' ? 'regions' : kind === 'councils' ? 'councils' : 'villages');
      cmsAjax({
        url: isNew ? base : base + '/' + editing.id,
        method: isNew ? 'POST' : 'PUT',
        data: JSON.stringify(payload),
        contentType: 'application/json',
        fallbackMsg: 'Could not save.',
        success: function () {
          CMS.toast('Saved successfully.', 'success');
          closeModal();
          loadAll();
        }
      });
    }
  });

  $('#addGeoBtn').text('+ Add Region');
  loadAll();
});
