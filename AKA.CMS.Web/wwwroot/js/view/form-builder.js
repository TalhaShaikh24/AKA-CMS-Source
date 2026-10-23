/* Dynamic Form Builder — palette (drag & drop), grid canvas, properties panel.
   State lives in `fields[]`; save sends the whole definition to /api/dynamic-forms. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();

  var PALETTE = [
    { group: 'Layout' },
    { type: 'section', label: 'Section - 1 Column', icon: '\u25a6', preset: 1 },
    { type: 'section', label: 'Section - 2 Columns', icon: '\u25a6', preset: 2 },
    { type: 'section', label: 'Section - 3 Columns', icon: '\u25a6', preset: 3 },
    { type: 'section', label: 'Section - 4 Columns', icon: '\u25a6', preset: 4 },
    { type: 'heading', label: 'Heading', icon: 'H' },
    { type: 'paragraph', label: 'Paragraph Text', icon: '\u2261' },
    { group: 'Inputs' },
    { type: 'text', label: 'Text Input', icon: 'T' },
    { type: 'email', label: 'Email', icon: '@' },
    { type: 'number', label: 'Number', icon: '#' },
    { type: 'password', label: 'Password', icon: '\u2022\u2022' },
    { type: 'textarea', label: 'Text Area', icon: '\u00b6' },
    { type: 'hidden', label: 'Hidden Input', icon: '\u25cc' },
    { group: 'Choice' },
    { type: 'select', label: 'Dropdown', icon: '\u25be' },
    { type: 'multiselect', label: 'Multi-Select (Select2)', icon: '\u25be\u25be' },
    { type: 'radio', label: 'Radio Buttons', icon: '\u25c9' },
    { type: 'checkboxGroup', label: 'Checkbox Group', icon: '\u2611' },
    { type: 'checkbox', label: 'Single Checkbox', icon: '\u2713' },
    { type: 'lookup', label: 'Lookup (other form)', icon: '\u2315' },
    { group: 'Date & Time' },
    { type: 'date', label: 'Date Picker', icon: '\ud83d\udcc5' },
    { type: 'time', label: 'Time', icon: '\ud83d\udd50' },
    { type: 'datetime', label: 'Date & Time', icon: '\ud83d\udcc6' },
    { group: 'Advanced' },
    { type: 'file', label: 'File Upload', icon: '\ud83d\udcce' },
    { type: 'grid', label: 'Grid / Table', icon: '\u229e' },
    { group: 'Actions' },
    { type: 'button', label: 'Button', icon: '\u25b8' }
  ];
  var TYPE_LABELS = {};
  PALETTE.forEach(function (p) { if (p.type && !TYPE_LABELS[p.type]) TYPE_LABELS[p.type] = p.label; });
  TYPE_LABELS.section = 'Section';
  var WIDTHS = [ { v: 12, l: 'Full width' }, { v: 6, l: 'Half' }, { v: 4, l: 'Third' }, { v: 3, l: 'Quarter' } ];

  var formId = $('#dfbFormId').val() || '';
  var fields = [];
  var selected = -1;
  var dragState = null; // {kind:'new', type} | {kind:'move', index}

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  function slug(text) {
    var s = String(text || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    return s || 'field';
  }

  function uniqueKey(base) {
    var key = base, n = 2;
    while (fields.some(function (f) { return f.fieldKey === key; })) key = base + '-' + (n++);
    return key;
  }

  function newField(type, presetCols) {
    var label = TYPE_LABELS[type] || 'Field';
    var f = {
      fieldKey: uniqueKey(slug(label)), label: label, fieldType: type,
      placeholder: '', helpText: '', isRequired: false, defaultValue: '',
      options: [], minLength: null, maxLength: null, minValue: null, maxValue: null,
      accept: '', choiceLayout: 'Vertical',
      buttonAction: null, regexPattern: '', validationMessage: '',
      lookupFormId: null, lookupFieldKey: '', gridColumns: [],
      sectionColumns: null, columnIndex: null,
      customJs: '', cssClass: '', customId: '', customAttributes: [], validationRules: [],
      inputMask: '', showInfoIcon: false, infoText: '',
      columnSpan: (type === 'heading' || type === 'paragraph') ? 12 : 6
    };
    if (CMSFormRenderer.OPTION_TYPES[type]) {
      f.options = [ { value: 'option-1', label: 'Option 1' }, { value: 'option-2', label: 'Option 2' } ];
    }
    if (type === 'section') {
      f.label = 'New Section'; f.columnSpan = 12;
      f.sectionColumns = presetCols === undefined ? 2 : (presetCols === 0 ? null : presetCols);
    }
    if (type === 'hidden') { f.label = 'Hidden Field'; f.columnSpan = 12; }
    if (type === 'button') { f.label = 'Submit'; f.buttonAction = 'submit'; f.columnSpan = 12; }
    if (type === 'grid') {
      f.label = 'Grid'; f.columnSpan = 12;
      f.gridColumns = [ { key: 'column-1', label: 'Column 1', type: 'text', options: [] } ];
    }
    if (type === 'lookup') { f.label = 'Lookup'; }
    return f;
  }

  /* ---------------- palette ---------------- */
  function renderPalette() {
    $('#dfbPalette').html(PALETTE.map(function (p) {
      if (p.group) return '<div class="dfb-pal-group">' + esc(p.group) + '</div>';
      return '<div class="dfb-pal-item" draggable="true" data-ptype="' + p.type + '"' +
        (p.preset !== undefined ? ' data-preset="' + p.preset + '"' : '') +
        ' data-search="' + esc((p.label + ' ' + p.type).toLowerCase()) + '">' +
        '<span class="dfb-pal-icon">' + esc(p.icon) + '</span><span>' + esc(p.label) + '</span></div>';
    }).join('') + '<p class="hint" id="dfbPalNoMatch" style="display:none;padding:8px 2px">No fields match your search.</p>');
    filterPalette($('#dfbPalSearch').val() || '');
  }

  /* Live search over the Fields palette: filters items as you type and
     hides group headers whose items are all filtered out. */
  function filterPalette(q) {
    q = $.trim(String(q || '')).toLowerCase();
    var anyVisible = false;
    $('#dfbPalette .dfb-pal-item').each(function () {
      var hit = !q || ($(this).data('search') || '').indexOf(q) >= 0;
      $(this).toggle(hit);
      if (hit) anyVisible = true;
    });
    $('#dfbPalette .dfb-pal-group').each(function () {
      var show = !q, $n = $(this).next();
      while ($n.length && !$n.hasClass('dfb-pal-group')) {
        if ($n.hasClass('dfb-pal-item') && $n.is(':visible')) { show = true; break; }
        $n = $n.next();
      }
      $(this).toggle(show);
    });
    $('#dfbPalNoMatch').toggle(!!q && !anyVisible);
  }

  $('#dfbPalSearch').on('input', function () {
    $('#dfbPalClear').prop('hidden', !$(this).val());
    filterPalette($(this).val());
  });
  $('#dfbPalClear').on('click', function () {
    $('#dfbPalSearch').val('').trigger('input').focus();
  });

  /* ---------------- canvas ----------------
     The canvas is a stack of areas: a leading "top" area (fields before the
     first section, span-grid layout), then one box per section. A section
     either keeps the legacy span-grid layout (sectionColumns = null) or an
     Elementor-style column layout (1-4 columns; fields stack per column). */
  /* Tree helpers: every field carries parentKey (its section's key;
     null = top level). Children render in array order within a parent. */
  function childrenIdx(parentKey) {
    var out = [];
    fields.forEach(function (f, i) { if ((f.parentKey || null) === (parentKey || null)) out.push(i); });
    return out;
  }

  function bucketsIdx(secIdx, n) {
    var cols = [];
    for (var c = 0; c < n; c++) cols.push([]);
    childrenIdx(fields[secIdx].fieldKey).forEach(function (i) {
      var ci = fields[i].columnIndex == null ? 0 : Math.min(n - 1, Math.max(0, fields[i].columnIndex));
      cols[ci].push(i);
    });
    return cols;
  }

  function descendantKeys(key) {
    var out = [key];
    fields.forEach(function (f) {
      if ((f.parentKey || null) === key && f.fieldType === 'section') out = out.concat(descendantKeys(f.fieldKey));
    });
    return out;
  }

  function layoutSegHtml(sf, secIdx) {
    var cur = sf.sectionColumns || '';
    return [{ v: 1, l: '1' }, { v: 2, l: '2' }, { v: 3, l: '3' }, { v: 4, l: '4' }].map(function (o) {
      return '<button type="button" data-seclayout="' + o.v + '" data-secidx="' + secIdx + '"' +
        (String(cur) === String(o.v) ? ' class="sel"' : '') + '>' + o.l + '</button>';
    }).join('');
  }

  function cardHtml(f, i) {
    var preview = CMSFormRenderer.fieldHtml(f, true);
    return '<div class="dfb-card' + (i === selected ? ' sel' : '') + '" data-index="' + i + '"' +
        ' style="grid-column: span ' + (f.columnSpan || 6) + '">' +
      '<div class="dfb-card-bar">' +
        '<span class="dfb-drag" draggable="true" data-drag="' + i + '" title="Drag to move">⠿</span>' +
        '<span class="dfb-card-type">' + esc(TYPE_LABELS[f.fieldType] || f.fieldType) + '</span>' +
        '<span class="dfb-card-actions">' +
          '<button type="button" data-dup="' + i + '" title="Duplicate">⧉</button>' +
          '<button type="button" data-del="' + i + '" title="Delete">✕</button>' +
        '</span>' +
      '</div>' +
      '<div class="dfb-card-body">' + preview + '</div>' +
    '</div>';
  }

  function itemHtmlB(i, depth) {
    if (fields[i].fieldType === 'section') {
      return '<div class="dfb-nested-box" style="grid-column:1/-1">' + sectionBoxHtml(i, depth) + '</div>';
    }
    return cardHtml(fields[i], i);
  }

  function areaHtml(parentKey, idxs, slim) {
    return '<div class="dfb-grid dfb-area' + (slim ? ' dfb-area-slim' : '') + '" data-area="' + (parentKey ? 'section' : 'top') + '" data-parent="' + esc(parentKey || '') + '">' +
      (idxs.length ? idxs.map(function (i) { return cardHtml(fields[i], i); }).join('')
                   : '<div class="dfb-col-empty" style="grid-column:1/-1">Drop fields here' + (parentKey ? '' : ' (before the first section)') + '</div>') +
      '</div>';
  }

  /* One level of the tree as HTML: runs of fields become grid areas,
     sections become boxes (recursively). */
  function levelHtml(parentKey, depth) {
    var kids = childrenIdx(parentKey);
    var html = '', run = [];
    function flush() { if (run.length) { html += areaHtml(parentKey, run, false); run = []; } }
    kids.forEach(function (i) {
      if (fields[i].fieldType === 'section') { flush(); html += sectionBoxHtml(i, depth); }
      else run.push(i);
    });
    flush();
    return html;
  }

  function sectionBoxHtml(secIdx, depth) {
    var sf = fields[secIdx];
    var layout = sf.sectionColumns || null;
    var html = '<div class="dfb-section-box' + (secIdx === selected ? ' sel' : '') + '" data-secbox="' + secIdx + '">' +
      '<div class="dfb-section-bar">' +
        '<span class="dfb-drag" draggable="true" data-secdrag="' + secIdx + '" title="Drag to move section">⠿</span>' +
        '<strong>' + esc(sf.label) + '</strong><span class="pill">Section</span>' +
        '<span class="dfb-layout-seg seg">' + layoutSegHtml(sf, secIdx) + '</span>' +
        '<span class="dfb-card-actions">' +
          '<button type="button" data-dup="' + secIdx + '" title="Duplicate section">⧉</button>' +
          '<button type="button" data-del="' + secIdx + '" title="Delete section">✕</button>' +
        '</span>' +
      '</div>';
    if (layout) {
      html += '<div class="dfb-cols-row" style="grid-template-columns:repeat(' + layout + ',1fr)">' +
        bucketsIdx(secIdx, layout).map(function (colIdxs, c) {
          return '<div class="dfb-col-zone" data-secidx="' + secIdx + '" data-col="' + c + '">' +
            (colIdxs.length ? colIdxs.map(function (ci) { return itemHtmlB(ci, depth + 1); }).join('')
                            : '<div class="dfb-col-empty" style="grid-column:1/-1">Drop fields here</div>') +
            '</div>';
        }).join('') + '</div>';
    } else {
      html += levelHtml(sf.fieldKey, depth + 1);
    }
    return html + '</div>';
  }

  function renderCanvas() {
    var $grid = $('#dfbGrid');
    $('#dfbEmpty').toggle(fields.length === 0);
    $('#dfbFieldCount').text(fields.length ? fields.length + ' field' + (fields.length === 1 ? '' : 's') : '');
    var html;
    if (!fields.length) {
      html = '<div class="dfb-grid dfb-area" data-area="top" data-parent=""></div>';
    } else {
      html = levelHtml(null, 0);
      // Keep a slim drop strip before the first section so top-level fields
      // can still be dropped above it.
      var rootKids = childrenIdx(null);
      if (rootKids.length && fields[rootKids[0]].fieldType === 'section') {
        html = areaHtml(null, [], true) + html;
      }
    }
    $grid.html(html);
    // The renderer wraps fields in its own grid cell — unwrap one level for the card body.
    $grid.find('.dfb-card-body > .dfb-cell, .dfb-card-body > .field').css('grid-column', 'auto');
    renderNavigator();
  }

  /* Switch a section between the legacy grid layout and column layouts.
     Grid -> columns distributes the section's direct fields round-robin;
     fewer columns clamps overflow into the last column. */
  function applySectionLayout(secIdx, newLayout) {
    var sf = fields[secIdx];
    if (!sf || sf.fieldType !== 'section') return;
    var oldLayout = sf.sectionColumns || null;
    sf.sectionColumns = newLayout;
    var idxs = childrenIdx(sf.fieldKey);
    if (!newLayout) { idxs.forEach(function (i) { fields[i].columnIndex = null; }); return; }
    if (!oldLayout) { idxs.forEach(function (i, k) { fields[i].columnIndex = k % newLayout; }); return; }
    idxs.forEach(function (i) { if ((fields[i].columnIndex || 0) >= newLayout) fields[i].columnIndex = newLayout - 1; });
  }

  function selectField(i) {
    selected = i;
    renderCanvas();
    renderProps();
  }

  /* ---------------- navigator (Elementor-style structure tree) ------------
     A floating panel mirroring the form structure: sections with their
     fields (grouped by column for column-layout sections). Click a row to
     select + reveal it on the canvas; drag rows to reorder — fields can
     move between sections/columns, sections move as whole blocks. */
  var collapsedSecs = new Set();
  var navDrag = null;

  function navIcon(type) {
    var found = null;
    PALETTE.forEach(function (p) { if (p.type === type && !found) found = p.icon; });
    return found || '•';
  }

  function navFieldRow(i, depth) {
    var f = fields[i];
    return '<div class="dfb-nav-row' + (i === selected ? ' sel' : '') + '" data-navidx="' + i + '" draggable="true" style="padding-left:' + (10 + depth * 16) + 'px">' +
      '<span class="dfb-nav-ico">' + esc(navIcon(f.fieldType)) + '</span>' +
      '<span class="dfb-nav-label">' + esc(f.label || TYPE_LABELS[f.fieldType] || f.fieldType) + '</span>' +
      '<span class="dfb-nav-meta">' + esc(TYPE_LABELS[f.fieldType] || f.fieldType) + '</span></div>';
  }

  function navSectionRow(i, depth) {
    var f = fields[i];
    var kids = childrenIdx(f.fieldKey).length;
    var collapsed = collapsedSecs.has(f);
    return '<div class="dfb-nav-row dfb-nav-sec' + (i === selected ? ' sel' : '') + '" data-navidx="' + i + '" draggable="true" style="padding-left:' + (4 + depth * 16) + 'px">' +
      '<button type="button" class="dfb-nav-caret" data-navcaret="' + i + '">' + (kids ? (collapsed ? '▸' : '▾') : '·') + '</button>' +
      '<span class="dfb-nav-ico">▦</span>' +
      '<span class="dfb-nav-label">' + esc(f.label || 'Section') + '</span>' +
      '<span class="dfb-nav-meta">' + (f.sectionColumns ? f.sectionColumns + ' col' : 'Section') + '</span></div>';
  }

  function navChildrenHtml(secIdx, depth) {
    var f = fields[secIdx];
    var html = '';
    if (f.sectionColumns) {
      bucketsIdx(secIdx, f.sectionColumns).forEach(function (colIdxs, c) {
        html += '<div class="dfb-nav-row dfb-nav-col" data-navcol="' + secIdx + ':' + c + '" style="padding-left:' + (10 + depth * 16) + 'px">' +
          '<span class="dfb-nav-ico">▥</span><span class="dfb-nav-label">Column ' + (c + 1) + '</span></div>';
        colIdxs.forEach(function (ci) {
          if (fields[ci].fieldType === 'section') {
            html += navSectionRow(ci, depth + 1);
            if (!collapsedSecs.has(fields[ci])) html += navChildrenHtml(ci, depth + 2);
          } else html += navFieldRow(ci, depth + 1);
        });
      });
      return html;
    }
    return navLevelHtml(f.fieldKey, depth);
  }

  function navLevelHtml(parentKey, depth) {
    var html = '';
    childrenIdx(parentKey).forEach(function (i) {
      if (fields[i].fieldType === 'section') {
        html += navSectionRow(i, depth);
        if (!collapsedSecs.has(fields[i])) html += navChildrenHtml(i, depth + 1);
      } else html += navFieldRow(i, depth);
    });
    return html;
  }

  function renderNavigator() {
    var $nav = $('#dfbNavTree');
    if (!$nav.length) return;
    $nav.html(navLevelHtml(null, 0) || '<p class="hint" style="padding:8px 10px">No fields yet — add some from the Fields panel.</p>');
  }

  function revealInCanvas(i) {
    var el = document.querySelector('.dfb-card[data-index="' + i + '"], .dfb-section-box[data-secbox="' + i + '"]');
    if (!el) return;
    el.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    el.classList.add('dfb-flash');
    setTimeout(function () { el.classList.remove('dfb-flash'); }, 1200);
  }

  /* The column a field visually sits in: only when its parent section
     uses a column layout. */
  function navColumnForField(i) {
    var f = fields[i];
    if (!f || !f.parentKey) return null;
    var sec = null;
    fields.forEach(function (x) { if (x.fieldKey === f.parentKey) sec = x; });
    return sec && sec.sectionColumns ? (f.columnIndex || 0) : null;
  }

  function navDoDrop(target, after) {
    var from = navDrag.index;
    var item = fields[from];
    if (!item) { renderCanvas(); return; }
    var ins, newParent = null, newCol = null;
    if (target.kind === 'column') {
      var secF = fields[target.secIdx];
      newParent = secF.fieldKey;
      newCol = target.col;
      var colItems = bucketsIdx(target.secIdx, secF.sectionColumns)[target.col];
      if (colItems.length) ins = colItems[colItems.length - 1] + 1;
      else {
        var kids = childrenIdx(secF.fieldKey);
        ins = target.secIdx + 1;
        for (var k = 0; k < kids.length; k++) {
          if ((fields[kids[k]].columnIndex || 0) > target.col) { ins = kids[k]; break; }
          ins = kids[k] + 1;
        }
      }
    } else {
      var t = fields[target.idx];
      if (!t) { renderCanvas(); return; }
      if (t.fieldType === 'section' && after && !navDrag.isSection) {
        // Field dropped onto a section row = into the section, at its start.
        newParent = t.fieldKey;
        newCol = t.sectionColumns ? 0 : null;
        ins = target.idx + 1;
      } else if (t.fieldType === 'section') {
        // Before/after a section = sibling position in the section's parent.
        newParent = t.parentKey || null;
        newCol = t.columnIndex == null ? null : t.columnIndex;
        ins = after ? target.idx + 1 : target.idx;
      } else {
        newParent = t.parentKey || null;
        newCol = navColumnForField(target.idx);
        ins = after ? target.idx + 1 : target.idx;
      }
    }
    if (item.fieldType === 'section' && newParent && descendantKeys(item.fieldKey).indexOf(newParent) >= 0) {
      CMS.toast('A section cannot be moved inside itself.', 'error');
      renderCanvas();
      return;
    }
    if (ins === from || ins === from + 1) { renderCanvas(); return; }
    fields.splice(from, 1);
    if (from < ins) ins--;
    item.parentKey = newParent;
    item.columnIndex = newParent ? newCol : null;
    fields.splice(ins, 0, item);
    selectField(ins);
    revealInCanvas(ins);
  }

  $('#dfbNavTree').on('click', '[data-navidx]', function () {
    var idx = Number($(this).data('navidx'));
    selectField(idx);
    revealInCanvas(idx);
  });
  $('#dfbNavTree').on('dragstart', '[data-navidx]', function (e) {
    var idx = Number($(this).data('navidx'));
    navDrag = { index: idx, isSection: fields[idx].fieldType === 'section' };
    e.originalEvent.dataTransfer.effectAllowed = 'move';
    e.originalEvent.dataTransfer.setData('text/plain', 'dfb-nav');
  });
  $('#dfbNavTree').on('dragover', '[data-navidx], [data-navcol]', function (e) {
    if (!navDrag) return;
    e.preventDefault();
    e.originalEvent.dataTransfer.dropEffect = 'move';
    navClearOver();
    var $row = $(this);
    if ($row.is('[data-navcol]')) { $row.addClass('dfb-nav-over-full'); return; }
    var r = this.getBoundingClientRect();
    var after = (e.originalEvent.clientY - r.top) > r.height / 2;
    $row.addClass(after ? 'dfb-nav-over-bottom' : 'dfb-nav-over-top');
  });
  $('#dfbNavTree').on('drop', '[data-navidx], [data-navcol]', function (e) {
    e.preventDefault();
    if (!navDrag) return;
    var $row = $(this);
    if ($row.is('[data-navcol]')) {
      var parts = String($row.data('navcol')).split(':');
      navDoDrop({ kind: 'column', secIdx: Number(parts[0]), col: Number(parts[1]) }, true);
    } else {
      var idx = Number($row.data('navidx'));
      var r = this.getBoundingClientRect();
      var after = (e.originalEvent.clientY - r.top) > r.height / 2;
      if (idx !== navDrag.index) navDoDrop({ kind: 'row', idx: idx }, after);
      else renderCanvas();
    }
    navDrag = null;
    navClearOver();
  });
  $(document).on('dragend', function () { navDrag = null; navClearOver(); });

  /* Panel show/hide + drag by its header (Elementor-style floating panel). */
  $('#dfbNavToggle').on('click', function () { $('#dfbNavigator').toggleClass('open'); });
  $('#dfbNavClose').on('click', function () { $('#dfbNavigator').removeClass('open'); });
  (function () {
    var head = document.getElementById('dfbNavHead'), panel = document.getElementById('dfbNavigator');
    if (!head || !panel) return;
    var sx = 0, sy = 0, ox = 0, oy = 0, moving = false;
    head.addEventListener('pointerdown', function (e) {
      if ($(e.target).closest('#dfbNavClose').length) return;
      var r = panel.getBoundingClientRect();
      moving = true; sx = e.clientX; sy = e.clientY; ox = r.left; oy = r.top;
      panel.style.left = r.left + 'px'; panel.style.top = r.top + 'px'; panel.style.right = 'auto';
      head.setPointerCapture(e.pointerId);
    });
    head.addEventListener('pointermove', function (e) {
      if (!moving) return;
      panel.style.left = (ox + e.clientX - sx) + 'px';
      panel.style.top = (oy + e.clientY - sy) + 'px';
    });
    head.addEventListener('pointerup', function () { moving = false; });
  })();

  /* ---------------- properties ---------------- */
  function optionsToText(options) {
    return (options || []).map(function (o) {
      return o.value === slug(o.label) || o.value === o.label ? o.label : o.value + ' | ' + o.label;
    }).join('\n');
  }

  function textToOptions(text) {
    return String(text || '').split('\n').map(function (line) {
      line = line.trim();
      if (!line) return null;
      var parts = line.split('|');
      if (parts.length > 1) return { value: slug(parts[0].trim()) || slug(parts[1]), label: parts.slice(1).join('|').trim() };
      return { value: slug(line), label: line };
    }).filter(Boolean);
  }

  function gridColumnsHtml(f) {
    var html = '<div class="field"><label>Columns</label><div id="ppGridCols">';
    (f.gridColumns || []).forEach(function (c, i) {
      html += '<div class="dfb-col-row">' +
        '<div class="dfb-col-head"><strong>Column ' + (i + 1) + '</strong>' +
        '<button type="button" class="dfb-grid-del" data-col-del="' + i + '" title="Remove column">✕</button></div>' +
        '<div class="form-grid">' +
          '<div class="field"><label>Key</label><input class="input pp-col-key" data-ci="' + i + '" value="' + esc(c.key) + '"></div>' +
          '<div class="field"><label>Label</label><input class="input pp-col-label" data-ci="' + i + '" value="' + esc(c.label) + '"></div>' +
        '</div>' +
        '<div class="field"><label>Type</label><select class="input pp-col-type" data-ci="' + i + '">' +
          ['text', 'number', 'date', 'select'].map(function (t) {
            return '<option value="' + t + '"' + (c.type === t ? ' selected' : '') + '>' + t + '</option>';
          }).join('') + '</select></div>';
      if (c.type === 'select') {
        html += '<div class="field"><label>Options</label><textarea class="input pp-col-options" data-ci="' + i + '" rows="3">' +
          esc(optionsToText(c.options)) + '</textarea><span class="hint">One per line. <code>value | Label</code></span></div>';
      }
      html += '</div>';
    });
    html += '</div><button class="btn btn-ghost btn-sm" id="ppAddCol" type="button">+ Add Column</button>' +
      '<span class="hint" style="display:block;margin-top:6px">Rows are added by the user when filling the form.</span></div>';
    return html;
  }

  function attrsEditorHtml(f) {
    var html = '<div class="field"><label>Custom Attributes</label><div id="ppAttrs">';
    (f.customAttributes || []).forEach(function (a, i) {
      html += '<div class="dfb-mini-row">' +
        '<input class="input pp-attr-name" data-ai="' + i + '" value="' + esc(a.name) + '" placeholder="data-name">' +
        '<input class="input pp-attr-value" data-ai="' + i + '" value="' + esc(a.value) + '" placeholder="value">' +
        '<button type="button" class="btn btn-ghost btn-sm" data-attr-del="' + i + '" title="Remove">✕</button></div>';
    });
    html += '</div><button type="button" class="btn btn-ghost btn-sm" id="ppAttrAdd">+ Add Attribute</button>' +
      '<span class="hint">Applied to the field control, e.g. data-track, data-group. Event attributes (onclick…) are not allowed.</span></div>';
    return html;
  }

  function rulesEditorHtml(f) {
    var html = '<div class="field"><label>More Validation Rules (regex)</label><div id="ppRules">';
    (f.validationRules || []).forEach(function (r, i) {
      html += '<div class="dfb-mini-row">' +
        '<input class="input pp-rule-pattern" data-ri="' + i + '" value="' + esc(r.pattern) + '" placeholder="Pattern, e.g. ^[A-Z]+$">' +
        '<input class="input pp-rule-message" data-ri="' + i + '" value="' + esc(r.message) + '" placeholder="Error message">' +
        '<button type="button" class="btn btn-ghost btn-sm" data-rule-del="' + i + '" title="Remove">✕</button></div>';
    });
    html += '</div><button type="button" class="btn btn-ghost btn-sm" id="ppRuleAdd">+ Add Rule</button>' +
      '<span class="hint">Checked in order after the main pattern; the first failing rule shows its own message.</span></div>';
    return html;
  }

  function advancedHtml(f) {
    var t = f.fieldType;
    var html = '<div class="dfb-props-sep">Advanced</div>';
    html += '<div class="field"><label>CSS Class</label><input class="input" id="ppCssClass" value="' + esc(f.cssClass || '') + '" placeholder="e.g. highlight big-text"></div>';
    html += '<div class="field"><label>Custom ID</label><input class="input" id="ppCustomId" value="' + esc(f.customId || '') + '" placeholder="e.g. patient-cnic"></div>';
    if (['text', 'email', 'password', 'textarea'].indexOf(t) >= 0) {
      html += '<div class="field"><label>Input Mask</label><input class="input" id="ppInputMask" value="' + esc(f.inputMask || '') + '" placeholder="e.g. 99999-9999999-9">' +
        '<span class="hint">9 = digit, a = letter, * = any character. CNIC: 99999-9999999-9 · Phone: 9999-9999999</span></div>';
    }
    html += attrsEditorHtml(f);
    html += '<div class="field"><label class="check-row"><input type="checkbox" id="ppShowInfo"' + (f.showInfoIcon ? ' checked' : '') + '><span class="check-label">Show info icon</span></label>' +
      '<input class="input" id="ppInfoText" value="' + esc(f.infoText || '') + '" placeholder="Info message (tooltip)" style="margin-top:6px">' +
      '<span class="hint">An (i) icon appears next to the label; hovering or focusing it shows this message as a tooltip.</span></div>';
    html += '<div class="field"><label>Custom Function (JavaScript)</label><textarea class="input dfb-code" id="ppCustomJs" rows="4" placeholder="Runs when this field changes">' + esc(f.customJs || '') + '</textarea>' +
      '<span class="hint">Available: ctx.value, ctx.values, ctx.el, ctx.setValue(key, val), ctx.showField(key), ctx.hideField(key). Buttons run on click.</span></div>';
    return html;
  }

  function renderProps() {
    var $p = $('#dfbProps');
    var f = fields[selected];
    $('#dfbPropsType').text(f ? (TYPE_LABELS[f.fieldType] || f.fieldType) : '');
    if (!f) { $p.html('<p class="hint">Select a field on the canvas to edit its properties.</p>'); return; }
    var t = f.fieldType;
    var isStatic = t === 'heading' || t === 'paragraph';
    var isSection = t === 'section';
    var isButton = t === 'button';
    var isHidden = t === 'hidden';
    var isGrid = t === 'grid';
    var html = '';
    html += '<div class="field"><label>' + (isSection ? 'Section Title' : isButton ? 'Button Text' : 'Label') + '</label><input class="input" id="ppLabel" value="' + esc(f.label) + '"></div>';
    html += '<div class="field"><label>Field Key</label><input class="input" id="ppKey" value="' + esc(f.fieldKey) + '"><span class="hint">Used as the data name. Lowercase, hyphens.</span></div>';
    html += '<div class="field"><label>Type</label><div><span class="pill">' + esc(TYPE_LABELS[t] || t) + '</span></div></div>';
    if (!isSection && !isHidden) {
      html += '<div class="field"><label>Width</label><select class="input" id="ppSpan">' +
        WIDTHS.map(function (w) { return '<option value="' + w.v + '"' + (f.columnSpan === w.v ? ' selected' : '') + '>' + w.l + '</option>'; }).join('') +
        '</select></div>';
    }
    if (!isStatic && !isSection && !isButton && !isHidden) {
      html += '<div class="field"><label class="check-row"><input type="checkbox" id="ppRequired"' + (f.isRequired ? ' checked' : '') + '><span class="check-label">Required</span></label></div>';
      html += '<div class="field"><label>Placeholder</label><input class="input" id="ppPlaceholder" value="' + esc(f.placeholder || '') + '"></div>';
    }
    if (!isStatic && !isSection && !isButton && !isGrid) {
      html += '<div class="field"><label>Default Value</label><input class="input" id="ppDefault" value="' + esc(f.defaultValue || '') + '"></div>';
    }
    html += '<div class="field"><label>Help Text</label><input class="input" id="ppHelp" value="' + esc(f.helpText || '') + '"></div>';
    if (isSection) {
      html += '<div class="field"><label>Columns</label><div class="seg">' + layoutSegHtml(f, selected) + '</div>' +
        '<span class="hint">How many columns this section has — drag fields into each column, Elementor-style.</span></div>';
    }
    if (isButton) {
      var ba = f.buttonAction || 'button';
      html += '<div class="field"><label>Button Type</label><div class="seg" id="ppBtnSeg">' +
        '<button type="button" data-baction="submit"' + (ba === 'submit' ? ' class="sel"' : '') + '>Submit</button>' +
        '<button type="button" data-baction="reset"' + (ba === 'reset' ? ' class="sel"' : '') + '>Reset</button>' +
        '<button type="button" data-baction="button"' + (ba === 'button' ? ' class="sel"' : '') + '>Button</button>' +
        '</div><span class="hint">Every form needs exactly one Submit button.</span></div>';
    }
    if (CMSFormRenderer.OPTION_TYPES[t]) {
      html += '<div class="field"><label>Options</label><textarea class="input" id="ppOptions" rows="5">' + esc(optionsToText(f.options)) + '</textarea>' +
        '<span class="hint">One per line. Use <code>value | Label</code> for a separate value.</span></div>';
    }
    if (t === 'radio' || t === 'checkboxGroup') {
      var lay = f.choiceLayout || 'Vertical';
      html += '<div class="field"><label>Layout</label><div class="seg" id="ppLayoutSeg">' +
        '<button type="button" data-layout="Vertical"' + (lay === 'Vertical' ? ' class="sel"' : '') + '>Vertical</button>' +
        '<button type="button" data-layout="Horizontal"' + (lay === 'Horizontal' ? ' class="sel"' : '') + '>Horizontal</button>' +
        '</div><span class="hint">Vertical stacks options; Horizontal places them side by side.</span></div>';
    }
    if (t === 'text' || t === 'textarea' || t === 'email' || t === 'password') {
      html += '<div class="form-grid"><div class="field"><label>Min Length</label><input class="input" type="number" id="ppMinLen" value="' + (f.minLength == null ? '' : f.minLength) + '"></div>' +
        '<div class="field"><label>Max Length</label><input class="input" type="number" id="ppMaxLen" value="' + (f.maxLength == null ? '' : f.maxLength) + '"></div></div>';
      html += '<div class="field"><label>Regex Pattern</label><input class="input" id="ppRegex" value="' + esc(f.regexPattern || '') + '" placeholder="e.g. ^\\d{11}$">' +
        '<span class="hint">Optional. The value must match this pattern.</span></div>';
      html += '<div class="field"><label>Validation Message</label><input class="input" id="ppRegexMsg" value="' + esc(f.validationMessage || '') + '" placeholder="Shown when the pattern does not match"></div>';
      html += rulesEditorHtml(f);
    }
    if (t === 'number') {
      html += '<div class="form-grid"><div class="field"><label>Min Value</label><input class="input" type="number" id="ppMinVal" value="' + (f.minValue == null ? '' : f.minValue) + '"></div>' +
        '<div class="field"><label>Max Value</label><input class="input" type="number" id="ppMaxVal" value="' + (f.maxValue == null ? '' : f.maxValue) + '"></div></div>';
    }
    if (t === 'file') {
      html += '<div class="field"><label>Accepted File Types</label><input class="input" id="ppAccept" value="' + esc(f.accept || '') + '" placeholder="e.g. .pdf,image/*"></div>';
    }
    if (isGrid) html += gridColumnsHtml(f);
    if (t === 'lookup') {
      html += '<div class="field"><label>Source Form</label><select class="input" id="ppLookupForm"><option value="">Select form…</option></select></div>';
      html += '<div class="field"><label>Source Field</label><select class="input" id="ppLookupField"><option value="">Select field…</option></select>' +
        '<span class="hint">SharePoint-style lookup: this dropdown is filled from the chosen field of the other form.</span></div>';
    }
    html += advancedHtml(f);
    html += '<div style="display:flex;gap:8px;margin-top:12px">' +
      '<button class="btn btn-ghost btn-sm" id="ppDup" type="button">Duplicate</button>' +
      '<button class="btn btn-ghost btn-sm" id="ppDel" type="button" style="color:var(--red-dark)">Delete Field</button></div>';
    $p.html(html);
    if (t === 'lookup') fillLookupForms(f);
  }

  /* ---------------- lookup property editors ---------------- */
  var lookupFormsCache = null;
  function fillLookupForms(f) {
    function apply(forms) {
      var $sel = $('#ppLookupForm');
      if (!$sel.length) return;
      $sel.html('<option value="">Select form…</option>' + forms
        .filter(function (x) { return String(x.formId) !== String(formId); })
        .map(function (x) {
          return '<option value="' + x.formId + '"' + (String(f.lookupFormId) === String(x.formId) ? ' selected' : '') + '>' +
            esc(x.title) + ' (' + esc(x.formKey) + ')</option>';
        }).join(''));
      if (f.lookupFormId) fillLookupFields(f);
    }
    if (lookupFormsCache) { apply(lookupFormsCache); return; }
    cmsAjax({
      url: '/api/dynamic-forms', method: 'GET', fallbackMsg: 'Could not load forms.',
      success: function (forms) { lookupFormsCache = forms || []; apply(lookupFormsCache); },
      error: function () { return true; }
    });
  }

  function fillLookupFields(f) {
    if (!f.lookupFormId) { $('#ppLookupField').html('<option value="">Select field…</option>'); return; }
    cmsAjax({
      url: '/api/dynamic-forms/' + f.lookupFormId, method: 'GET', fallbackMsg: 'Could not load fields.',
      success: function (src) {
        var $sel = $('#ppLookupField');
        if (!$sel.length) return;
        $sel.html('<option value="">Select field…</option>' + (src.fields || []).map(function (x) {
          return '<option value="' + esc(x.fieldKey) + '"' + (f.lookupFieldKey === x.fieldKey ? ' selected' : '') + '>' +
            esc(x.label) + ' (' + esc(x.fieldKey) + ')</option>';
        }).join(''));
      },
      error: function () { return true; }
    });
  }

  function numOrNull(v) { v = $.trim(v || ''); return v === '' ? null : Number(v); }

  $('#dfbProps').on('input change', 'input, textarea, select', function () {
    var f = fields[selected];
    if (!f) return;
    var $t = $(this);
    // Grid column editor (class-based, index in data-ci).
    if ($t.hasClass('pp-col-key')) { f.gridColumns[Number($t.data('ci'))].key = slug($t.val()); renderCanvas(); return; }
    if ($t.hasClass('pp-col-label')) { f.gridColumns[Number($t.data('ci'))].label = $t.val(); renderCanvas(); return; }
    if ($t.hasClass('pp-col-options')) { f.gridColumns[Number($t.data('ci'))].options = textToOptions($t.val()); renderCanvas(); return; }
    if ($t.hasClass('pp-col-type')) { f.gridColumns[Number($t.data('ci'))].type = $t.val(); renderCanvas(); renderProps(); return; }
    if ($t.hasClass('pp-attr-name')) { f.customAttributes[Number($t.data('ai'))].name = $.trim($t.val()); return; }
    if ($t.hasClass('pp-attr-value')) { f.customAttributes[Number($t.data('ai'))].value = $t.val(); return; }
    if ($t.hasClass('pp-rule-pattern')) { f.validationRules[Number($t.data('ri'))].pattern = $t.val(); return; }
    if ($t.hasClass('pp-rule-message')) { f.validationRules[Number($t.data('ri'))].message = $t.val(); return; }
    var id = this.id;
    if (id === 'ppLabel') { f.label = $(this).val(); }
    else if (id === 'ppKey') { f.fieldKey = slug($(this).val()) || f.fieldKey; }
    else if (id === 'ppSpan') { f.columnSpan = Number($(this).val()); }
    else if (id === 'ppRequired') { f.isRequired = $(this).is(':checked'); }
    else if (id === 'ppPlaceholder') { f.placeholder = $(this).val(); }
    else if (id === 'ppDefault') { f.defaultValue = $(this).val(); }
    else if (id === 'ppHelp') { f.helpText = $(this).val(); }
    else if (id === 'ppOptions') { f.options = textToOptions($(this).val()); }
    else if (id === 'ppMinLen') { f.minLength = numOrNull($(this).val()); }
    else if (id === 'ppMaxLen') { f.maxLength = numOrNull($(this).val()); }
    else if (id === 'ppMinVal') { f.minValue = numOrNull($(this).val()); }
    else if (id === 'ppMaxVal') { f.maxValue = numOrNull($(this).val()); }
    else if (id === 'ppAccept') { f.accept = $(this).val(); }
    else if (id === 'ppRegex') { f.regexPattern = $(this).val(); }
    else if (id === 'ppRegexMsg') { f.validationMessage = $(this).val(); }
    else if (id === 'ppLookupForm') {
      f.lookupFormId = $(this).val() ? Number($(this).val()) : null;
      f.lookupFieldKey = '';
      renderCanvas(); fillLookupFields(f); return;
    }
    else if (id === 'ppLookupField') { f.lookupFieldKey = $(this).val(); }
    else if (id === 'ppCssClass') { f.cssClass = $(this).val(); }
    else if (id === 'ppCustomId') { f.customId = $(this).val(); }
    else if (id === 'ppInputMask') { f.inputMask = $(this).val(); }
    else if (id === 'ppInfoText') { f.infoText = $(this).val(); }
    else if (id === 'ppShowInfo') { f.showInfoIcon = $(this).is(':checked'); }
    else if (id === 'ppCustomJs') { f.customJs = $(this).val(); }
    else return;
    renderCanvas();
  });

  $('#dfbProps').on('click', '#ppDel', function () { deleteField(selected); });
  $('#dfbProps').on('click', '#ppDup', function () { duplicateField(selected); });
  $('#dfbProps').on('click', '#ppBtnSeg button', function () {
    var f = fields[selected];
    if (!f) return;
    f.buttonAction = $(this).data('baction');
    renderProps(); renderCanvas();
  });
  $('#dfbProps').on('click', '#ppAddCol', function () {
    var f = fields[selected];
    if (!f || f.fieldType !== 'grid') return;
    var n = (f.gridColumns || []).length + 1;
    f.gridColumns.push({ key: 'column-' + n, label: 'Column ' + n, type: 'text', options: [] });
    renderProps(); renderCanvas();
  });
  $('#dfbProps').on('click', '[data-col-del]', function () {
    var f = fields[selected];
    if (!f || f.fieldType !== 'grid') return;
    f.gridColumns.splice(Number($(this).data('col-del')), 1);
    renderProps(); renderCanvas();
  });
  $('#dfbProps').on('click', '#ppAttrAdd', function () {
    var f = fields[selected];
    if (!f) return;
    f.customAttributes = f.customAttributes || [];
    f.customAttributes.push({ name: '', value: '' });
    renderProps();
  });
  $('#dfbProps').on('click', '[data-attr-del]', function () {
    var f = fields[selected];
    if (!f) return;
    f.customAttributes.splice(Number($(this).data('attr-del')), 1);
    renderProps();
  });
  $('#dfbProps').on('click', '#ppRuleAdd', function () {
    var f = fields[selected];
    if (!f) return;
    f.validationRules = f.validationRules || [];
    f.validationRules.push({ pattern: '', message: '' });
    renderProps();
  });
  $('#dfbProps').on('click', '[data-rule-del]', function () {
    var f = fields[selected];
    if (!f) return;
    f.validationRules.splice(Number($(this).data('rule-del')), 1);
    renderProps();
  });
  $('#dfbPalToggle').on('click', function () {
    var collapsed = $('#dfbPalPane').toggleClass('collapsed').hasClass('collapsed');
    $('.dfb-layout').toggleClass('pal-collapsed', collapsed);
  });

  /* Resizable panes: drag the gutters between Fields / Canvas / Properties.
     Widths persist in localStorage so the user's layout survives reloads. */
  (function initPaneResize() {
    var layout = document.querySelector('.dfb-layout');
    if (!layout) return;
    try {
      var pw = localStorage.getItem('dfbPalW'), rw = localStorage.getItem('dfbPropsW');
      if (pw) layout.style.setProperty('--pal-w', pw + 'px');
      if (rw) layout.style.setProperty('--props-w', rw + 'px');
    } catch (e) { /* storage unavailable */ }
    $('.dfb-gutter').each(function () {
      var gutter = this;
      gutter.addEventListener('pointerdown', function (e) {
        e.preventDefault();
        var side = gutter.getAttribute('data-gutter');
        var pane = document.getElementById(side === 'left' ? 'dfbPalPane' : 'dfbPropsPane');
        if (!pane) return;
        var startX = e.clientX;
        var startW = pane.getBoundingClientRect().width;
        var minW = side === 'left' ? 170 : 230;
        gutter.setPointerCapture(e.pointerId);
        gutter.classList.add('dragging');
        document.body.classList.add('dfb-resizing');
        function onMove(ev) {
          var dx = ev.clientX - startX;
          var w = side === 'left' ? startW + dx : startW - dx;
          w = Math.max(minW, Math.min(560, w));
          layout.style.setProperty(side === 'left' ? '--pal-w' : '--props-w', w + 'px');
          try { localStorage.setItem(side === 'left' ? 'dfbPalW' : 'dfbPropsW', String(Math.round(w))); } catch (err) { /* ignore */ }
        }
        function onUp() {
          gutter.removeEventListener('pointermove', onMove);
          gutter.removeEventListener('pointerup', onUp);
          gutter.classList.remove('dragging');
          document.body.classList.remove('dfb-resizing');
        }
        gutter.addEventListener('pointermove', onMove);
        gutter.addEventListener('pointerup', onUp);
      });
    });
  })();
  $('#dfbProps').on('click', '#ppLayoutSeg button', function () {
    var f = fields[selected];
    if (!f) return;
    f.choiceLayout = $(this).data('layout');
    renderCanvas();
  });

  function deleteField(i) {
    if (i < 0 || i >= fields.length) return;
    var removed = fields[i];
    if (removed.fieldType === 'section') {
      // Children move up to the deleted section's parent (they are not lost).
      fields.forEach(function (c) {
        if ((c.parentKey || null) === removed.fieldKey) c.parentKey = removed.parentKey || null;
      });
    }
    fields.splice(i, 1);
    selected = -1;
    renderCanvas(); renderProps();
  }

  function duplicateField(i) {
    if (i < 0 || i >= fields.length) return;
    var copy = JSON.parse(JSON.stringify(fields[i]));
    copy.fieldKey = uniqueKey(copy.fieldKey + '-copy');
    copy.label = copy.label + ' (copy)';
    fields.splice(i + 1, 0, copy);
    selectField(i + 1);
  }

  /* ---------------- canvas interactions ---------------- */
  $('#dfbGrid').on('click', '.dfb-card', function (e) {
    if ($(e.target).closest('[data-del],[data-dup]').length) return;
    selectField(Number($(this).data('index')));
  });
  $('#dfbGrid').on('click', '[data-del]', function (e) { e.stopPropagation(); deleteField(Number($(this).data('del'))); });
  $('#dfbGrid').on('click', '[data-dup]', function (e) { e.stopPropagation(); duplicateField(Number($(this).data('dup'))); });

  /* ---------------- drag & drop with drop-zone highlight ---------------- */
  var hotEl = null;
  function setHot(el) {
    if (hotEl === el) return;
    clearHot();
    hotEl = el || null;
    if (hotEl) hotEl.classList.add('dfb-hot');
  }
  function clearHot() { if (hotEl) { hotEl.classList.remove('dfb-hot'); hotEl = null; } }

  /* Insertion flat-index for a span-grid area (top / legacy section). */
  function areaInsertIndex($area, y) {
    // Only cards that live directly in THIS area (nested boxes hold their own).
    var $cards = $area.find('.dfb-card').filter(function () { return $(this).closest('.dfb-area')[0] === $area[0]; });
    var ins = null;
    $cards.each(function () {
      var r = this.getBoundingClientRect();
      if (ins === null && y < r.top + r.height / 2) ins = Number($(this).data('index'));
    });
    if (ins !== null) return ins;
    if ($cards.length) return Number($cards.last().data('index')) + 1;
    // Empty area: insert where this area sits in its parent level.
    var parentKey = $area.data('parent') || null;
    if (parentKey) {
      var secIdx = fields.findIndex(function (f) { return f.fieldKey === parentKey; });
      return secIdx >= 0 ? secIdx + 1 : fields.length;
    }
    var firstSec = fields.findIndex(function (f) { return (f.parentKey || null) === null && f.fieldType === 'section'; });
    return firstSec >= 0 ? firstSec : fields.length;
  }

  function columnInsertIndex(secIdx, col, y) {
    var $zone = $('.dfb-col-zone[data-secidx="' + secIdx + '"][data-col="' + col + '"]');
    var items = [];
    var before = null;
    $zone.children().each(function () {
      var $c = $(this), flat = null;
      if ($c.hasClass('dfb-card')) flat = Number($c.data('index'));
      else if ($c.hasClass('dfb-nested-box')) flat = Number($c.find('[data-secbox]').first().data('secbox'));
      if (flat === null || isNaN(flat)) return;
      items.push(flat);
      var r = this.getBoundingClientRect();
      if (before === null && y < r.top + r.height / 2) before = flat;
    });
    if (before !== null) return before;
    if (items.length) return items[items.length - 1] + 1;
    // Empty column: before the first child of a later column, else after the
    // section's last child, else right after the section itself.
    var kids = childrenIdx(fields[secIdx].fieldKey);
    for (var k = 0; k < kids.length; k++) { if ((fields[kids[k]].columnIndex || 0) > col) return kids[k]; }
    return kids.length ? kids[kids.length - 1] + 1 : secIdx + 1;
  }

  function placeField(idx, colIdx, parentKey) {
    parentKey = parentKey || null;
    if (dragState.kind === 'new') {
      var nf = newField(dragState.type, dragState.preset);
      nf.parentKey = parentKey;
      nf.columnIndex = parentKey ? colIdx : null;
      fields.splice(idx, 0, nf);
      selectField(idx);
      return;
    }
    var from = dragState.index;
    if (from === null || from === undefined || from === idx || from === idx - 1) { renderCanvas(); return; }
    var item = fields.splice(from, 1)[0];
    if (from < idx) idx--;
    // A section can never land inside itself or one of its own sections.
    if (item.fieldType === 'section' && parentKey && descendantKeys(item.fieldKey).indexOf(parentKey) >= 0) {
      fields.splice(from, 0, item);
      renderCanvas();
      CMS.toast('A section cannot be moved inside itself.', 'error');
      return;
    }
    item.parentKey = parentKey;
    item.columnIndex = parentKey ? colIdx : null;
    fields.splice(idx, 0, item);
    selectField(idx);
  }

  /* Moving a section now moves just its marker row — its fields follow
     automatically because they point at the section by key. Reorder happens
     among the section's siblings (same parent). */
  function dropSectionBlock(y) {
    var from = dragState.index;
    var item = fields[from];
    if (!item) { renderCanvas(); return; }
    var parentKey = item.parentKey || null;
    var $box = $('.dfb-section-box[data-secbox="' + from + '"]');
    var $container = $box.parent();
    var targetObj = null;
    $container.children('.dfb-section-box, .dfb-nested-box').each(function () {
      if (targetObj) return;
      var $c = $(this);
      var bi = Number($c.is('[data-secbox]') ? $c.data('secbox') : $c.find('[data-secbox]').first().data('secbox'));
      if (isNaN(bi) || bi === from) return;
      var r = this.getBoundingClientRect();
      if (y < r.top + r.height / 2) targetObj = fields[bi];
    });
    fields.splice(from, 1);
    var ins;
    if (targetObj) {
      ins = fields.indexOf(targetObj);
    } else {
      var sibs = fields.filter(function (f) { return f.fieldType === 'section' && (f.parentKey || null) === parentKey; });
      ins = sibs.length ? fields.indexOf(sibs[sibs.length - 1]) + 1 : fields.length;
    }
    fields.splice(ins, 0, item);
    selectField(ins);
  }

  $('#dfbCanvas').on('dragover', function (e) {
    if (!dragState) return;
    e.preventDefault();
    e.originalEvent.dataTransfer.dropEffect = dragState.kind === 'new' ? 'copy' : 'move';
    $(this).addClass('dfb-over');
    var target = null;
    if (dragState.kind === 'section') target = $(e.target).closest('.dfb-section-box, .dfb-area')[0] || null;
    else target = resolveDropZone(e);
    setHot(target);
  });
  $('#dfbCanvas').on('dragleave', function (e) {
    if (!$(e.target).closest('#dfbCanvas').length || e.relatedTarget && !$.contains(this, e.relatedTarget)) {
      $(this).removeClass('dfb-over'); clearHot();
    }
  });
  $('#dfbCanvas').on('drop', function (e) {
    e.preventDefault();
    $(this).removeClass('dfb-over');
    if (!dragState) return;
    var y = e.originalEvent.clientY;
    if (dragState.kind === 'section') {
      dropSectionBlock(y);
    } else {
      var zone = resolveDropZone(e);
      if (zone) {
        var $zone = $(zone);
        if ($zone.hasClass('dfb-col-zone')) {
          var sIdx = Number($zone.data('secidx'));
          placeField(columnInsertIndex(sIdx, Number($zone.data('col')), y), Number($zone.data('col')), fields[sIdx].fieldKey);
        }
        else placeField(areaInsertIndex($zone, y), null, $zone.data('parent') || null);
      } else {
        // No zones on the canvas at all — append at the end.
        placeField(fields.length, null, null);
      }
    }
    clearHot();
    dragState = null;
  });
  $(document).on('dragend', function () { dragState = null; clearHot(); $('#dfbCanvas').removeClass('dfb-over'); });

  /* Section bar: click selects the section; layout buttons switch its layout. */
  $('#dfbGrid').on('click', '.dfb-section-bar', function (e) {
    if ($(e.target).closest('[data-del],[data-dup],[data-seclayout],[data-secdrag]').length) return;
    selectField(Number($(this).closest('.dfb-section-box').data('secbox')));
  });
  $(document).on('click', '[data-seclayout]', function (e) {
    e.stopPropagation();
    var secIdx = Number($(this).data('secidx'));
    if (isNaN(secIdx) || !fields[secIdx]) secIdx = selected;
    var v = $(this).data('seclayout');
    applySectionLayout(secIdx, v === '' || v == null ? null : Number(v));
    selectField(secIdx);
  });

  /* Delete key removes the selected field (when not typing in an input). */
  $(document).on('keydown', function (e) {
    if (e.key !== 'Delete' || selected < 0) return;
    var t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.tagName === 'SELECT' || t.isContentEditable)) return;
    deleteField(selected);
  });

  /* ---------------- form settings ---------------- */
  $('#dfbDescToggle').on('click', function () {
    var $row = $('#dfbDescRow');
    $row.prop('hidden', !$row.prop('hidden'));
    if (!$row.prop('hidden')) $('#dfbDesc').focus();
  });
  $('#dfbTitle').on('input', function () {
    var $key = $('#dfbKey');
    if (formId === '' && !$key.data('touched')) $key.val(slug($(this).val()));
  });
  $('#dfbKey').on('input', function () { $(this).data('touched', true); });

  /* ---------------- load / save ---------------- */
  function loadForm() {
    if (!formId) {
      // A new form starts completely empty. Saving requires exactly one
      // Submit button — the save check below enforces that with an error.
      fields = [];
      renderPalette(); renderCanvas(); renderProps();
      return;
    }
    cmsAjax({
      url: '/api/dynamic-forms/' + formId, method: 'GET',
      fallbackMsg: 'Could not load form.',
      success: function (f) {
        document.title = 'Edit — ' + f.title + ' · Form Builder';
        $('#dfbTitle').val(f.title);
        $('#dfbKey').val(f.formKey).data('touched', true);
        $('#dfbDesc').val(f.description || '');
        if (f.description) $('#dfbDescRow').prop('hidden', false);
        $('#dfbActive').prop('checked', !!f.isActive);
        $('#dfbMultiStep').prop('checked', !!f.isMultiStep);
        fields = (f.fields || []).map(function (x) {
          return {
            fieldKey: x.fieldKey, label: x.label, fieldType: x.fieldType,
            placeholder: x.placeholder || '', helpText: x.helpText || '',
            isRequired: !!x.isRequired, defaultValue: x.defaultValue || '',
            options: x.options || [], minLength: x.minLength, maxLength: x.maxLength,
            minValue: x.minValue, maxValue: x.maxValue, accept: x.accept || '',
            choiceLayout: x.choiceLayout || 'Vertical',
            buttonAction: x.buttonAction || null, regexPattern: x.regexPattern || '',
            validationMessage: x.validationMessage || '',
            lookupFormId: x.lookupFormId || null, lookupFieldKey: x.lookupFieldKey || '',
            gridColumns: x.gridColumns || [],
            customJs: x.customJs || '', cssClass: x.cssClass || '', customId: x.customId || '',
            customAttributes: (x.customAttributes || []).map(function (a) { return { name: a.name || '', value: a.value || '' }; }),
            validationRules: (x.validationRules || []).map(function (r) { return { pattern: r.pattern || '', message: r.message || '' }; }),
            inputMask: x.inputMask || '', showInfoIcon: !!x.showInfoIcon, infoText: x.infoText || '',
            sectionColumns: x.sectionColumns == null ? null : x.sectionColumns,
            columnIndex: x.columnIndex == null ? null : x.columnIndex,
            columnSpan: x.columnSpan || 6
          };
        });
        renderPalette(); renderCanvas(); renderProps();
      }
    });
  }

  $('#dfbSaveBtn').on('click', function () {
    var title = $.trim($('#dfbTitle').val());
    var key = slug($('#dfbKey').val());
    if (!title) { CMS.toast('Form title is required.', 'error'); $('#dfbTitle').focus(); return; }
    if (!key) { CMS.toast('Form key is required.', 'error'); $('#dfbKey').focus(); return; }
    if (!fields.length) { CMS.toast('Add at least one field.', 'error'); return; }
    var submitCount = fields.filter(function (f) { return f.fieldType === 'button' && f.buttonAction === 'submit'; }).length;
    if (submitCount !== 1) {
      CMS.toast('The form must contain exactly one Submit button (found ' + submitCount + '). Add a Button field and set its type to Submit.', 'error');
      return;
    }
    for (var gi = 0; gi < fields.length; gi++) {
      if (fields[gi].fieldType === 'grid' && !(fields[gi].gridColumns || []).length) {
        CMS.toast('Grid "' + fields[gi].label + '" needs at least one column.', 'error'); return;
      }
      if (fields[gi].fieldType === 'lookup' && (!fields[gi].lookupFormId || !fields[gi].lookupFieldKey)) {
        CMS.toast('Lookup "' + fields[gi].label + '" needs a source form and source field.', 'error'); return;
      }
    }
    var payload = {
      formKey: key, title: title,
      description: $.trim($('#dfbDesc').val()) || null,
      isActive: $('#dfbActive').is(':checked'),
      isMultiStep: $('#dfbMultiStep').is(':checked'),
      fields: fields.map(function (f, i) {
        return {
          fieldKey: f.fieldKey, label: f.label, fieldType: f.fieldType,
          placeholder: f.placeholder || null, helpText: f.helpText || null,
          isRequired: !!f.isRequired, defaultValue: f.defaultValue || null,
          options: CMSFormRenderer.OPTION_TYPES[f.fieldType] ? (f.options || []) : [],
          minLength: f.minLength, maxLength: f.maxLength,
          minValue: f.minValue, maxValue: f.maxValue,
          accept: f.accept || null, choiceLayout: f.choiceLayout || 'Vertical',
          buttonAction: f.fieldType === 'button' ? (f.buttonAction || 'button') : null,
          regexPattern: $.trim(f.regexPattern || '') || null,
          validationMessage: $.trim(f.validationMessage || '') || null,
          lookupFormId: f.fieldType === 'lookup' ? (f.lookupFormId || null) : null,
          lookupFieldKey: f.fieldType === 'lookup' ? (f.lookupFieldKey || null) : null,
          gridColumns: f.fieldType === 'grid' ? (f.gridColumns || []) : [],
          customJs: f.customJs || null, cssClass: f.cssClass || null, customId: f.customId || null,
          customAttributes: (f.customAttributes || []).filter(function (a) { return a.name; }),
          validationRules: (f.validationRules || []).filter(function (r) { return r.pattern; }),
          inputMask: f.inputMask || null, showInfoIcon: !!f.showInfoIcon, infoText: f.infoText || null,
          sectionColumns: f.fieldType === 'section' ? (f.sectionColumns || null) : null,
          columnIndex: f.fieldType === 'section' ? null : (f.columnIndex == null ? null : f.columnIndex),
          columnSpan: (f.fieldType === 'section' || f.fieldType === 'hidden') ? 12 : (f.columnSpan || 6),
          sortOrder: i
        };
      })
    };
    cmsAjax({
      url: formId ? '/api/dynamic-forms/' + formId : '/api/dynamic-forms',
      method: formId ? 'PUT' : 'POST', json: true, data: payload,
      fallbackMsg: 'Could not save form.',
      success: function (res) {
        CMS.toast('Form saved.', 'success');
        if (!formId && res && res.formId) {
          window.location.href = '/DynamicForms/Builder/' + res.formId;
        } else {
          selected = -1; loadForm();
        }
      }
    });
  });

  $('#dfbPreviewBtn').on('click', function () {
    // Preview the CURRENT in-memory definition (unsaved changes included),
    // so the user can verify the form before saving it.
    if (!fields.length) { CMS.toast('Add at least one field to preview.', 'error'); return; }
    var formDef = {
      title: $.trim($('#dfbTitle').val()) || 'Untitled Form',
      description: $.trim($('#dfbDesc').val()),
      isMultiStep: $('#dfbMultiStep').is(':checked'),
      fields: fields.map(function (f, i) {
        var c = JSON.parse(JSON.stringify(f));
        c.sortOrder = i;
        return c;
      })
    };
    $('#dfbPreviewTitle').text(formDef.title);
    $('#dfbPreviewDesc').text(formDef.description || '');
    $('#dfbPreviewModal').addClass('open');
    // Render after the modal is visible so Select2 measures widths correctly.
    setTimeout(function () { CMSFormRenderer.render($('#dfbPreviewBody'), formDef); }, 30);
  });

  loadForm();
});
