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
  var $tabs = $('#geoTabs .tab');
  var $panels = $('.tab-panel');
  // Force initial state via inline style so it works regardless of CSS cascade.
  $panels.each(function (i) { this.style.display = i === 0 ? 'block' : 'none'; });
  $tabs.on('click', function () {
    var idx = $tabs.index(this);
    activeTab = $(this).attr('data-tab');
    $tabs.removeClass('active');
    $(this).addClass('active');
    $panels.removeClass('active').each(function (i) { this.style.display = i === idx ? 'block' : 'none'; });
    $panels.eq(idx).addClass('active');
    $('#addGeoBtn').text('+ Add ' + META[activeTab].title);
    renderTab(activeTab); // data already loaded on page init; just re-render cached
  });

  /* ---------- load ---------- */
  function loadTab(kind) {
    var loaders = {
      regions: function () {
        cmsAjax({ url: '/api/geography/regions?includeInactive=true', method: 'GET',
          fallbackMsg: 'Could not load regions.',
          success: function (res) { regions = res || []; renderRegions(); fillParentOptions(); },
          error: function () { $('#regionRows').html('<div class="hint geo-empty">Could not load regions. <button type="button" class="btn btn-ghost btn-sm" onclick="location.reload()">Retry</button></div>'); } });
      },
      councils: function () {
        cmsAjax({ url: '/api/geography/councils?includeInactive=true', method: 'GET',
          fallbackMsg: 'Could not load local councils.',
          success: function (res) { councils = res || []; renderCouncils(); },
          error: function () { $('#councilRows').html('<div class="hint geo-empty">Could not load local councils. <button type="button" class="btn btn-ghost btn-sm" onclick="location.reload()">Retry</button></div>'); } });
      },
      villages: function () {
        cmsAjax({ url: '/api/geography/villages?includeInactive=true', method: 'GET',
          fallbackMsg: 'Could not load villages.',
          success: function (res) { villages = res || []; renderVillages(); },
          error: function () { $('#villageRows').html('<div class="hint geo-empty">Could not load villages. <button type="button" class="btn btn-ghost btn-sm" onclick="location.reload()">Retry</button></div>'); } });
      }
    };
    if (loaders[kind]) loaders[kind]();
  }
  function loadAll() { loadTab('regions'); loadTab('councils'); loadTab('villages'); }

  function statusBadge(active) {
    return '<span class="badge ' + (active ? 'st-active' : 'st-ltfu') + '">' + (active ? 'Active' : 'Inactive') + '</span>';
  }
  function editBtn(kind, id) {
    return '<button class="btn btn-ghost btn-sm geo-edit" data-kind="' + kind + '" data-edit="' + id + '" data-permission="Geography:Write" type="button">Edit</button>';
  }
  function geoCard(name, sub, active, kind, id) {
    return '<div class="geo-card">' +
      '<div class="geo-card-main"><div class="geo-card-name">' + esc(name) + '</div>' +
      (sub ? '<div class="geo-card-sub">' + esc(sub) + '</div>' : '') + '</div>' +
      '<div class="geo-card-side">' + statusBadge(active) + editBtn(kind, id) + '</div>' +
      '</div>';
  }

  function renderTab(kind) {
    if (kind === 'regions') renderRegions();
    else if (kind === 'councils') renderCouncils();
    else if (kind === 'villages') renderVillages();
  }

  function renderRegions() {
    var html = regions.map(function (r) {
      return geoCard(r.regionName, null, r.isActive, 'regions', r.regionId);
    }).join('');
    $('#regionRows').html(html || '<div class="hint geo-empty">No regions found.</div>');
    if (window.CMS && typeof CMS.applyPermissions === 'function') CMS.applyPermissions(document);
  }
  function renderCouncils() {
    var html = councils.map(function (c) {
      return geoCard(c.councilName, c.regionName, c.isActive, 'councils', c.councilId);
    }).join('');
    $('#councilRows').html(html || '<div class="hint geo-empty">No local councils found.</div>');
    if (window.CMS && typeof CMS.applyPermissions === 'function') CMS.applyPermissions(document);
  }
  function renderVillages() {
    var html = villages.map(function (v) {
      return geoCard(v.villageName, v.councilName, v.isActive, 'villages', v.villageId);
    }).join('');
    $('#villageRows').html(html || '<div class="hint geo-empty">No villages found.</div>');
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
        data: payload,
        json: true,
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
