/* ==========================================================================
   Dynamic Form Builder — drag & drop form editor (jQuery).

   How it works, in one paragraph:
   The whole form lives in one plain array, `fields`. Every entry is a
   field object (label, type, options, parent section, column, ...).
   The three panels on screen are just views of that array:
     - Palette  = the list of field types you can add
     - Canvas   = the form itself, rendered with CMSFormRenderer
     - Properties = the editor for the currently selected field
   Any change edits the array and then re-renders the panels. Nothing is
   saved until "Save Form" sends the whole array to /api/dynamic-forms.

   Sections are fields too (fieldType "section"). A field belongs to a
   section through `parentKey` (the section's fieldKey, or null for the
   top level). That is the whole nesting model — moving a section moves
   only its own row; its fields follow because they point at it by key.
   ========================================================================== */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();

  /* ------------------------------------------------------------------
     Palette: the field types the user can add, grouped for display.
     `preset` only exists on section rows: it is the column count the
     new section starts with (1-4).
     ------------------------------------------------------------------ */
  var PALETTE = [
    { group: 'Layout' },
    { type: 'section', label: 'Section - 1 Column', icon: '▦', preset: 1 },
    { type: 'section', label: 'Section - 2 Columns', icon: '▦', preset: 2 },
    { type: 'section', label: 'Section - 3 Columns', icon: '▦', preset: 3 },
    { type: 'section', label: 'Section - 4 Columns', icon: '▦', preset: 4 },
    { type: 'heading', label: 'Heading', icon: 'H' },
    { type: 'paragraph', label: 'Paragraph Text', icon: '≡' },
    { type: 'link', label: 'Hyperlink', icon: '🔗' },
    { group: 'Inputs' },
    { type: 'text', label: 'Text Input', icon: 'T' },
    { type: 'email', label: 'Email', icon: '@' },
    { type: 'number', label: 'Number', icon: '#' },
    { type: 'password', label: 'Password', icon: '••' },
    { type: 'textarea', label: 'Text Area', icon: '¶' },
    { type: 'hidden', label: 'Hidden Input', icon: '◌' },
    { group: 'Choice' },
    { type: 'select', label: 'Dropdown', icon: '▾' },
    { type: 'multiselect', label: 'Multi-Select (Select2)', icon: '▾▾' },
    { type: 'radio', label: 'Radio Buttons', icon: '◉' },
    { type: 'checkboxGroup', label: 'Checkbox Group', icon: '☑' },
    { type: 'checkbox', label: 'Single Checkbox', icon: '✓' },
    { type: 'lookup', label: 'Lookup (other form)', icon: '⌕' },
    { group: 'Date & Time' },
    { type: 'date', label: 'Date Picker', icon: '📅' },
    { type: 'time', label: 'Time', icon: '🕐' },
    { type: 'datetime', label: 'Date & Time', icon: '📆' },
    { group: 'Advanced' },
    { type: 'file', label: 'File Upload', icon: '📎' },
    { type: 'grid', label: 'Grid / Table', icon: '⊞' },
    { group: 'Actions' },
    { type: 'button', label: 'Button', icon: '▸' }
  ];

  // Short label for each type, used on canvas cards and in the Navigator.
  var TYPE_LABELS = {};
  PALETTE.forEach(function (item) {
    if (item.type && !TYPE_LABELS[item.type]) TYPE_LABELS[item.type] = item.label;
  });
  TYPE_LABELS.section = 'Section';

  // The widths offered in the Properties panel.
  var WIDTHS = [
    { v: 12, l: 'Full width' },
    { v: 6, l: 'Half' },
    { v: 4, l: 'Third' },
    { v: 3, l: 'Quarter' }
  ];

  // The form being edited. `selected` is its index, or -1 when nothing
  // is selected. `dragState` / `navDrag` only live during a drag.
  var formId = $('#dfbFormId').val() || '';
  var fields = [];
  var selected = -1;
  var dragState = null; // { kind: 'new'|'move'|'section', type?, preset?, index? }
  var navDrag = null;   // { index, isSection }
  var collapsedSecs = new Set(); // section field objects collapsed in Navigator
  var lookupFormsCache = null;

  /* ------------------------------------------------------------------
     Small helpers
     ------------------------------------------------------------------ */

  // Escape text for HTML so a label can never break the markup.
  function esc(text) {
    return String(text == null ? '' : text).replace(/[&<>"']/g, function (ch) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch];
    });
  }

  // "Form Title" -> "form-title". Used for field keys and the form key.
  function slug(text) {
    var clean = String(text || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    return clean || 'field';
  }

  // A field key that does not clash with any existing field.
  function uniqueKey(base) {
    var key = base;
    var n = 2;
    while (fields.some(function (f) { return f.fieldKey === key; })) {
      key = base + '-' + (n++);
    }
    return key;
  }

  function isSection(field) {
    return field && field.fieldType === 'section';
  }

  // Indexes of the direct children of one parent (null = top level).
  function childrenIdx(parentKey) {
    var out = [];
    fields.forEach(function (f, i) {
      if ((f.parentKey || null) === (parentKey || null)) out.push(i);
    });
    return out;
  }

  // A section's children split into its columns (only for column layouts).
  function bucketsIdx(secIdx, columnCount) {
    var buckets = [];
    var c;
    for (c = 0; c < columnCount; c++) buckets.push([]);
    childrenIdx(fields[secIdx].fieldKey).forEach(function (i) {
      var col = fields[i].columnIndex == null ? 0 : Math.min(columnCount - 1, Math.max(0, fields[i].columnIndex));
      buckets[col].push(i);
    });
    return buckets;
  }

  // A section key plus the keys of every section nested inside it.
  function descendantKeys(key) {
    var out = [key];
    fields.forEach(function (f) {
      if ((f.parentKey || null) === key && isSection(f)) out = out.concat(descendantKeys(f.fieldKey));
    });
    return out;
  }

  // Border/divider display for a section: the stored value wins; when it
  // was never set, top-level sections show them and nested ones hide them.
  function secShow(field, which) {
    var value = which === 'border' ? field.showBorder : field.showDivider;
    if (value === null || value === undefined) return !field.parentKey;
    return !!value;
  }

  // A fresh field of the given type, with the defaults the builder uses.
  function newField(type, presetCols) {
    var f = {
      fieldKey: uniqueKey(slug(TYPE_LABELS[type] || 'Field')),
      label: TYPE_LABELS[type] || 'Field',
      fieldType: type,
      placeholder: '', helpText: '', isRequired: false, defaultValue: '',
      options: [], minLength: null, maxLength: null, minValue: null, maxValue: null,
      accept: '', choiceLayout: 'Vertical',
      buttonAction: null, regexPattern: '', validationMessage: '',
      lookupFormId: null, lookupFieldKey: '', gridColumns: [],
      sectionColumns: null, columnIndex: null, showBorder: null, showDivider: null,
      customJs: '', cssClass: '', customId: '', customAttributes: [], validationRules: [],
      inputMask: '', showInfoIcon: false, infoText: '',
      columnSpan: (type === 'heading' || type === 'paragraph') ? 12 : 6
    };
    if (CMSFormRenderer.OPTION_TYPES[type]) {
      f.options = [{ value: 'option-1', label: 'Option 1' }, { value: 'option-2', label: 'Option 2' }];
    }
    if (isSection(f)) {
      f.label = 'New Section';
      f.columnSpan = 12;
      // No preset = the standard 2-column section; preset 0 = legacy grid.
      f.sectionColumns = presetCols === undefined ? 2 : (presetCols === 0 ? null : presetCols);
    }
    if (type === 'hidden') { f.label = 'Hidden Field'; f.columnSpan = 12; }
    if (type === 'button') { f.label = 'Submit'; f.buttonAction = 'submit'; f.columnSpan = 12; }
    if (type === 'link') { f.label = 'Hyperlink'; f.columnSpan = 12; }
    if (type === 'grid') {
      f.label = 'Grid';
      f.columnSpan = 12;
      f.gridColumns = [{ key: 'column-1', label: 'Column 1', type: 'text', options: [] }];
    }
    if (type === 'lookup') f.label = 'Lookup';
    return f;
  }

  /* ------------------------------------------------------------------
     Palette panel
     ------------------------------------------------------------------ */
  function renderPalette() {
    var html = PALETTE.map(function (item) {
      if (item.group) return '<div class="dfb-pal-group">' + esc(item.group) + '</div>';
      var preset = item.preset !== undefined ? ' data-preset="' + item.preset + '"' : '';
      return '<div class="dfb-pal-item" draggable="true" data-ptype="' + item.type + '"' + preset +
        ' data-search="' + esc((item.label + ' ' + item.type).toLowerCase()) + '">' +
        '<span class="dfb-pal-icon">' + esc(item.icon) + '</span><span>' + esc(item.label) + '</span></div>';
    }).join('');
    html += '<p class="hint" id="dfbPalNoMatch" style="display:none;padding:8px 2px">No fields match your search.</p>';
    $('#dfbPalette').html(html);
    filterPalette($('#dfbPalSearch').val() || '');
  }

  // Live search: show only matching palette items, and hide a group
  // header when none of its items match.
  function filterPalette(query) {
    query = $.trim(String(query || '')).toLowerCase();
    var anyVisible = false;
    $('#dfbPalette .dfb-pal-item').each(function () {
      var hit = !query || ($(this).data('search') || '').indexOf(query) >= 0;
      $(this).toggle(hit);
      if (hit) anyVisible = true;
    });
    $('#dfbPalette .dfb-pal-group').each(function () {
      var show = !query;
      var next = $(this).next();
      while (next.length && !next.hasClass('dfb-pal-group')) {
        if (next.hasClass('dfb-pal-item') && next.is(':visible')) { show = true; break; }
        next = next.next();
      }
      $(this).toggle(show);
    });
    $('#dfbPalNoMatch').toggle(!!query && !anyVisible);
  }

  $('#dfbPalSearch').on('input', function () {
    $('#dfbPalClear').prop('hidden', !$(this).val());
    filterPalette($(this).val());
  });
  $('#dfbPalClear').on('click', function () {
    $('#dfbPalSearch').val('').trigger('input').focus();
  });
  $('#dfbPalToggle').on('click', function () {
    var collapsed = $('#dfbPalPane').toggleClass('collapsed').hasClass('collapsed');
    $('.dfb-layout').toggleClass('pal-collapsed', collapsed);
  });

  /* ------------------------------------------------------------------
     Canvas panel: renders `fields` as cards and section boxes.

     The canvas is a stack of "areas": a leading top area (fields before
     the first section), then one box per section. Inside a section,
     fields either flow in a 12-column span grid (legacy, when
     sectionColumns is null) or stack inside Elementor-style columns.
     A section box can itself contain section boxes (nested sections).
     ------------------------------------------------------------------ */

  // The 1/2/3/4 buttons on a section bar.
  function layoutSegHtml(sectionField, secIdx) {
    var current = sectionField.sectionColumns || '';
    return [1, 2, 3, 4].map(function (n) {
      var selectedClass = String(current) === String(n) ? ' class="sel"' : '';
      return '<button type="button" data-seclayout="' + n + '" data-secidx="' + secIdx + '"' + selectedClass + '>' + n + '</button>';
    }).join('');
  }

  // One field card: a drag handle, the type pill, duplicate/delete
  // buttons, and a live preview of the field from the renderer.
  function cardHtml(field, i) {
    var preview = CMSFormRenderer.fieldHtml(field, true);
    return '<div class="dfb-card' + (i === selected ? ' sel' : '') + '" data-index="' + i + '"' +
      ' style="grid-column: span ' + (field.columnSpan || 6) + '">' +
      '<div class="dfb-card-bar">' +
      '<span class="dfb-drag" draggable="true" data-drag="' + i + '" title="Drag to move">⠿</span>' +
      '<span class="dfb-card-type">' + esc(TYPE_LABELS[field.fieldType] || field.fieldType) + '</span>' +
      '<span class="dfb-card-actions">' +
      '<button type="button" data-dup="' + i + '" title="Duplicate">⧉</button>' +
      '<button type="button" data-del="' + i + '" title="Delete">✕</button>' +
      '</span></div>' +
      '<div class="dfb-card-body">' + preview + '</div>' +
      '</div>';
  }

  // A canvas item: a section becomes a whole box, anything else a card.
  function itemHtmlB(i, depth) {
    if (isSection(fields[i])) {
      return '<div class="dfb-nested-box" style="grid-column:1/-1">' + sectionBoxHtml(i, depth) + '</div>';
    }
    return cardHtml(fields[i], i);
  }

  // A drop area holding a run of plain fields (span-grid layout).
  function areaHtml(parentKey, idxs, slim) {
    var inner;
    if (idxs.length) {
      inner = idxs.map(function (i) { return cardHtml(fields[i], i); }).join('');
    } else {
      inner = '<div class="dfb-col-empty" style="grid-column:1/-1">Drop fields here' +
        (parentKey ? '' : ' (before the first section)') + '</div>';
    }
    return '<div class="dfb-grid dfb-area' + (slim ? ' dfb-area-slim' : '') + '" data-area="' +
      (parentKey ? 'section' : 'top') + '" data-parent="' + esc(parentKey || '') + '">' + inner + '</div>';
  }

  // One level of the tree: runs of plain fields become areas, sections
  // become boxes, in field order.
  function levelHtml(parentKey, depth) {
    var html = '';
    var run = [];
    function flushRun() {
      if (run.length) { html += areaHtml(parentKey, run, false); run = []; }
    }
    childrenIdx(parentKey).forEach(function (i) {
      if (isSection(fields[i])) { flushRun(); html += sectionBoxHtml(i, depth); }
      else run.push(i);
    });
    flushRun();
    return html;
  }

  // A section box: its bar (drag handle, title, layout buttons,
  // duplicate/delete) plus its children, either in columns or as a
  // nested level.
  function sectionBoxHtml(secIdx, depth) {
    var sectionField = fields[secIdx];
    var layout = sectionField.sectionColumns || null;
    var html = '<div class="dfb-section-box' + (secIdx === selected ? ' sel' : '') +
      (secShow(sectionField, 'border') ? '' : ' dfb-noborder') +
      (secShow(sectionField, 'divider') ? '' : ' dfb-nodivider') + '" data-secbox="' + secIdx + '">' +
      '<div class="dfb-section-bar">' +
      '<span class="dfb-drag" draggable="true" data-secdrag="' + secIdx + '" title="Drag to move section">⠿</span>' +
      '<strong>' + esc(sectionField.label) + '</strong><span class="pill">Section</span>' +
      '<span class="dfb-layout-seg seg">' + layoutSegHtml(sectionField, secIdx) + '</span>' +
      '<span class="dfb-card-actions">' +
      '<button type="button" data-dup="' + secIdx + '" title="Duplicate section">⧉</button>' +
      '<button type="button" data-del="' + secIdx + '" title="Delete section">✕</button>' +
      '</span></div>';
    if (layout) {
      html += '<div class="dfb-cols-row" style="grid-template-columns:repeat(' + layout + ',1fr)">' +
        bucketsIdx(secIdx, layout).map(function (colIdxs, c) {
          var zoneInner;
          if (colIdxs.length) zoneInner = colIdxs.map(function (ci) { return itemHtmlB(ci, depth + 1); }).join('');
          else zoneInner = '<div class="dfb-col-empty" style="grid-column:1/-1">Drop fields here</div>';
          return '<div class="dfb-col-zone" data-secidx="' + secIdx + '" data-col="' + c + '">' + zoneInner + '</div>';
        }).join('') + '</div>';
    } else {
      html += levelHtml(sectionField.fieldKey, depth + 1);
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
      // Keep a slim drop strip above the first section, so top-level
      // fields can still be dropped above it.
      var rootKids = childrenIdx(null);
      if (rootKids.length && isSection(fields[rootKids[0]])) {
        html = areaHtml(null, [], true) + html;
      }
    }
    $grid.html(html);
    // The renderer wraps fields in its own grid cell — unwrap one level
    // so the card body, not the cell, controls the width.
    $grid.find('.dfb-card-body > .dfb-cell, .dfb-card-body > .field').css('grid-column', 'auto');
    renderNavigator();
  }

  // Switch a section between legacy grid and column layouts.
  // Grid -> columns deals the direct fields round-robin into columns;
  // fewer columns clamps overflow into the last column.
  function applySectionLayout(secIdx, newLayout) {
    var sectionField = fields[secIdx];
    if (!sectionField || !isSection(sectionField)) return;
    var oldLayout = sectionField.sectionColumns || null;
    sectionField.sectionColumns = newLayout;
    var idxs = childrenIdx(sectionField.fieldKey);
    if (!newLayout) {
      idxs.forEach(function (i) { fields[i].columnIndex = null; });
      return;
    }
    if (!oldLayout) {
      idxs.forEach(function (i, k) { fields[i].columnIndex = k % newLayout; });
      return;
    }
    idxs.forEach(function (i) {
      if ((fields[i].columnIndex || 0) >= newLayout) fields[i].columnIndex = newLayout - 1;
    });
  }

  // Select a field: highlight its card and show it in Properties.
  function selectField(i) {
    selected = i;
    renderCanvas();
    renderProps();
  }

  /* ------------------------------------------------------------------
     Navigator: the floating structure tree (Elementor-style).
     Click a row to select it on the canvas; drag rows to reorder.
     Sections move as whole blocks — their fields follow by key.
     ------------------------------------------------------------------ */
  function navIcon(type) {
    var found = null;
    PALETTE.forEach(function (item) {
      if (item.type === type && !found) found = item.icon;
    });
    return found || '•';
  }

  function navFieldRow(i, depth) {
    var f = fields[i];
    var requiredStar = f.isRequired ? ' <span class="req">*</span>' : '';
    return '<div class="dfb-nav-row' + (i === selected ? ' sel' : '') + '" data-navidx="' + i +
      '" draggable="true" style="padding-left:' + (10 + depth * 16) + 'px">' +
      '<span class="dfb-nav-ico">' + esc(navIcon(f.fieldType)) + '</span>' +
      '<span class="dfb-nav-label">' + esc(f.label || TYPE_LABELS[f.fieldType] || f.fieldType) + requiredStar + '</span>' +
      '<span class="dfb-nav-meta">' + esc(TYPE_LABELS[f.fieldType] || f.fieldType) + '</span></div>';
  }

  function navSectionRow(i, depth) {
    var f = fields[i];
    var kidCount = childrenIdx(f.fieldKey).length;
    var collapsed = collapsedSecs.has(f);
    var caret = kidCount ? (collapsed ? '▸' : '▾') : '·';
    return '<div class="dfb-nav-row dfb-nav-sec' + (i === selected ? ' sel' : '') + '" data-navidx="' + i +
      '" draggable="true" style="padding-left:' + (4 + depth * 16) + 'px">' +
      '<button type="button" class="dfb-nav-caret" data-navcaret="' + i + '">' + caret + '</button>' +
      '<span class="dfb-nav-ico">▦</span>' +
      '<span class="dfb-nav-label">' + esc(f.label || 'Section') + '</span>' +
      '<span class="dfb-nav-meta">' + (f.sectionColumns ? f.sectionColumns + ' col' : 'Section') + '</span></div>';
  }

  function navChildrenHtml(secIdx, depth) {
    var f = fields[secIdx];
    if (f.sectionColumns) {
      var html = '';
      bucketsIdx(secIdx, f.sectionColumns).forEach(function (colIdxs, c) {
        html += '<div class="dfb-nav-row dfb-nav-col" data-navcol="' + secIdx + ':' + c +
          '" style="padding-left:' + (10 + depth * 16) + 'px">' +
          '<span class="dfb-nav-ico">▥</span><span class="dfb-nav-label">Column ' + (c + 1) + '</span></div>';
        colIdxs.forEach(function (ci) {
          if (isSection(fields[ci])) {
            html += navSectionRow(ci, depth + 1);
            if (!collapsedSecs.has(fields[ci])) html += navChildrenHtml(ci, depth + 2);
          } else {
            html += navFieldRow(ci, depth + 1);
          }
        });
      });
      return html;
    }
    return navLevelHtml(f.fieldKey, depth);
  }

  function navLevelHtml(parentKey, depth) {
    var html = '';
    childrenIdx(parentKey).forEach(function (i) {
      if (isSection(fields[i])) {
        html += navSectionRow(i, depth);
        if (!collapsedSecs.has(fields[i])) html += navChildrenHtml(i, depth + 1);
      } else {
        html += navFieldRow(i, depth);
      }
    });
    return html;
  }

  function renderNavigator() {
    var $nav = $('#dfbNavTree');
    if (!$nav.length) return;
    $nav.html(navLevelHtml(null, 0) ||
      '<p class="hint" style="padding:8px 10px">No fields yet — add some from the Fields panel.</p>');
  }

  // Scroll a canvas card/section into view and flash it once.
  function revealInCanvas(i) {
    var el = document.querySelector('.dfb-card[data-index="' + i + '"], .dfb-section-box[data-secbox="' + i + '"]');
    if (!el) return;
    el.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    el.classList.add('dfb-flash');
    setTimeout(function () { el.classList.remove('dfb-flash'); }, 1200);
  }

  // The column a field visually sits in — only when its parent section
  // uses a column layout, otherwise null.
  function navColumnForField(i) {
    var f = fields[i];
    if (!f || !f.parentKey) return null;
    var sectionField = null;
    fields.forEach(function (x) { if (x.fieldKey === f.parentKey) sectionField = x; });
    return sectionField && sectionField.sectionColumns ? (f.columnIndex || 0) : null;
  }

  // Move the dragged Navigator row to its drop target.
  // `target` is either a column row or a field/section row, and `after`
  // says whether the drop was on the row's lower half.
  function navDoDrop(target, after) {
    var from = navDrag.index;
    var item = fields[from];
    if (!item) { renderCanvas(); return; }
    var ins;
    var newParent = null;
    var newCol = null;
    if (target.kind === 'column') {
      var sectionField = fields[target.secIdx];
      newParent = sectionField.fieldKey;
      newCol = target.col;
      var colItems = bucketsIdx(target.secIdx, sectionField.sectionColumns)[target.col];
      if (colItems.length) {
        ins = colItems[colItems.length - 1] + 1;
      } else {
        // Empty column: insert before the first child of a later column,
        // otherwise right after the section's last child.
        var kids = childrenIdx(sectionField.fieldKey);
        ins = target.secIdx + 1;
        for (var k = 0; k < kids.length; k++) {
          if ((fields[kids[k]].columnIndex || 0) > target.col) { ins = kids[k]; break; }
          ins = kids[k] + 1;
        }
      }
    } else {
      var t = fields[target.idx];
      if (!t) { renderCanvas(); return; }
      if (isSection(t) && after && !navDrag.isSection) {
        // A field dropped on a section row goes inside it, at the start.
        newParent = t.fieldKey;
        newCol = t.sectionColumns ? 0 : null;
        ins = target.idx + 1;
      } else if (isSection(t)) {
        // Before/after a section = a sibling position in its parent.
        newParent = t.parentKey || null;
        newCol = t.columnIndex == null ? null : t.columnIndex;
        ins = after ? target.idx + 1 : target.idx;
      } else {
        newParent = t.parentKey || null;
        newCol = navColumnForField(target.idx);
        ins = after ? target.idx + 1 : target.idx;
      }
    }
    if (isSection(item) && newParent && descendantKeys(item.fieldKey).indexOf(newParent) >= 0) {
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

  function navClearOver() {
    $('#dfbNavTree .dfb-nav-over-top, #dfbNavTree .dfb-nav-over-bottom, #dfbNavTree .dfb-nav-over-full')
      .removeClass('dfb-nav-over-top dfb-nav-over-bottom dfb-nav-over-full');
  }

  $('#dfbNavTree').on('click', '[data-navcaret]', function (e) {
    e.stopPropagation();
    var f = fields[Number($(this).data('navcaret'))];
    if (f) {
      if (collapsedSecs.has(f)) collapsedSecs.delete(f); else collapsedSecs.add(f);
    }
    renderNavigator();
  });
  $('#dfbNavTree').on('click', '[data-navidx]', function () {
    var idx = Number($(this).data('navidx'));
    selectField(idx);
    revealInCanvas(idx);
  });
  $('#dfbNavTree').on('dragstart', '[data-navidx]', function (e) {
    var idx = Number($(this).data('navidx'));
    navDrag = { index: idx, isSection: isSection(fields[idx]) };
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
    var rect = this.getBoundingClientRect();
    var after = (e.originalEvent.clientY - rect.top) > rect.height / 2;
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
      var rect = this.getBoundingClientRect();
      var after = (e.originalEvent.clientY - rect.top) > rect.height / 2;
      if (idx !== navDrag.index) navDoDrop({ kind: 'row', idx: idx }, after);
      else renderCanvas();
    }
    navDrag = null;
    navClearOver();
  });
  $(document).on('dragend', function () { navDrag = null; navClearOver(); });

  // Show/hide the Navigator panel, and drag it by its header.
  $('#dfbNavToggle').on('click', function () { $('#dfbNavigator').toggleClass('open'); });
  $('#dfbNavClose').on('click', function () { $('#dfbNavigator').removeClass('open'); });
  (function initNavigatorDrag() {
    var head = document.getElementById('dfbNavHead');
    var panel = document.getElementById('dfbNavigator');
    if (!head || !panel) return;
    var startX = 0, startY = 0, originLeft = 0, originTop = 0, moving = false;
    head.addEventListener('pointerdown', function (e) {
      if ($(e.target).closest('#dfbNavClose').length) return;
      var rect = panel.getBoundingClientRect();
      moving = true;
      startX = e.clientX; startY = e.clientY;
      originLeft = rect.left; originTop = rect.top;
      panel.style.left = rect.left + 'px';
      panel.style.top = rect.top + 'px';
      panel.style.right = 'auto';
      head.setPointerCapture(e.pointerId);
    });
    head.addEventListener('pointermove', function (e) {
      if (!moving) return;
      panel.style.left = (originLeft + e.clientX - startX) + 'px';
      panel.style.top = (originTop + e.clientY - startY) + 'px';
    });
    head.addEventListener('pointerup', function () { moving = false; });
  })();

  /* ------------------------------------------------------------------
     Properties panel: the editor for the selected field.
     Each editor is a small HTML builder; renderProps() picks which
     editors a field type gets (a section gets Columns + Display, a
     button gets Button Type, an option field gets Options, and so on).
     ------------------------------------------------------------------ */

  // Options as text: one per line, "value | Label" when they differ.
  function optionsToText(options) {
    return (options || []).map(function (o) {
      if (o.value === slug(o.label) || o.value === o.label) return o.label;
      return o.value + ' | ' + o.label;
    }).join('\n');
  }

  // Text back to options: "value | Label" or a bare label (value = slug).
  function textToOptions(text) {
    return String(text || '').split('\n').map(function (line) {
      line = line.trim();
      if (!line) return null;
      var parts = line.split('|');
      if (parts.length > 1) {
        return { value: slug(parts[0].trim()) || slug(parts[1]), label: parts.slice(1).join('|').trim() };
      }
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
        '<span class="hint">9 = digit, a = letter, * = any character. CNIC: 99999-9999999-9 · Phone: 9999-9999999. ' +
        'If Placeholder is empty, the mask pattern shows as the placeholder (e.g. _____-_______-_).</span></div>';
    }
    html += attrsEditorHtml(f);
    html += '<div class="field"><label class="check-row"><input type="checkbox" id="ppShowInfo"' + (f.showInfoIcon ? ' checked' : '') + '><span class="check-label">Show info icon</span></label>' +
      '<input class="input" id="ppInfoText" value="' + esc(f.infoText || '') + '" placeholder="Info message (tooltip)" style="margin-top:6px">' +
      '<span class="hint">An (i) icon appears next to the label; hovering or focusing it shows this message as a tooltip.</span></div>';
    html += '<div class="field"><label>Custom Function (JavaScript)</label><textarea class="input dfb-code" id="ppCustomJs" rows="4" placeholder="Runs when this field changes">' + esc(f.customJs || '') + '</textarea>' +
      '<span class="hint">Available: ctx.value, ctx.values, ctx.el, ctx.setValue(key, val), ctx.showField(key), ctx.hideField(key). Buttons and links run on click.</span></div>';
    return html;
  }

  function renderProps() {
    var $panel = $('#dfbProps');
    var f = fields[selected];
    $('#dfbPropsType').text(f ? (TYPE_LABELS[f.fieldType] || f.fieldType) : '');
    if (!f) {
      $panel.html('<p class="hint">Select a field on the canvas to edit its properties.</p>');
      return;
    }
    var t = f.fieldType;
    var isStatic = t === 'heading' || t === 'paragraph';
    var isSectionField = isSection(f);
    var isButton = t === 'button';
    var isHidden = t === 'hidden';
    var isGrid = t === 'grid';
    var isLink = t === 'link';
    var labelTitle = isSectionField ? 'Section Title' : isButton ? 'Button Text' : isLink ? 'Link Text' : 'Label';
    var html = '';
    html += '<div class="field"><label>' + labelTitle + '</label><input class="input" id="ppLabel" value="' + esc(f.label) + '"></div>';
    html += '<div class="field"><label>Field Key</label><input class="input" id="ppKey" value="' + esc(f.fieldKey) + '"><span class="hint">Used as the data name. Lowercase, hyphens.</span></div>';
    html += '<div class="field"><label>Type</label><div><span class="pill">' + esc(TYPE_LABELS[t] || t) + '</span></div></div>';
    if (!isSectionField && !isHidden) {
      html += '<div class="field"><label>Width</label><select class="input" id="ppSpan">' +
        WIDTHS.map(function (w) {
          return '<option value="' + w.v + '"' + (f.columnSpan === w.v ? ' selected' : '') + '>' + w.l + '</option>';
        }).join('') + '</select></div>';
    }
    if (!isStatic && !isSectionField && !isButton && !isHidden && !isLink) {
      html += '<div class="field"><label class="check-row"><input type="checkbox" id="ppRequired"' + (f.isRequired ? ' checked' : '') + '><span class="check-label">Required</span></label></div>';
      html += '<div class="field"><label>Placeholder</label><input class="input" id="ppPlaceholder" value="' + esc(f.placeholder || '') + '"></div>';
    }
    if (!isStatic && !isSectionField && !isButton && !isGrid) {
      // For a hyperlink the "default value" IS the URL it points to.
      var defaultTitle = isLink ? 'Link URL' : 'Default Value';
      var defaultPlaceholder = isLink ? ' placeholder="https://example.com"' : '';
      html += '<div class="field"><label>' + defaultTitle + '</label><input class="input" id="ppDefault" value="' + esc(f.defaultValue || '') + '"' + defaultPlaceholder + '></div>';
    }
    html += '<div class="field"><label>Help Text</label><input class="input" id="ppHelp" value="' + esc(f.helpText || '') + '"></div>';
    if (isSectionField) {
      html += '<div class="field"><label>Columns</label><div class="seg">' + layoutSegHtml(f, selected) + '</div>' +
        '<span class="hint">How many columns this section has — drag fields into each column, Elementor-style.</span></div>';
      html += '<div class="field"><label>Display</label>' +
        '<label class="check-row"><input type="checkbox" id="ppShowBorder"' + (secShow(f, 'border') ? ' checked' : '') + '><span class="check-label">Show border</span></label>' +
        '<label class="check-row"><input type="checkbox" id="ppShowDivider"' + (secShow(f, 'divider') ? ' checked' : '') + '><span class="check-label">Show divider under title</span></label>';
      if (f.parentKey) html += '<span class="hint">Child section — border and divider stay hidden unless you turn them on.</span>';
      html += '</div>';
    }
    if (isButton) {
      var buttonAction = f.buttonAction || 'button';
      html += '<div class="field"><label>Button Type</label><div class="seg" id="ppBtnSeg">' +
        '<button type="button" data-baction="submit"' + (buttonAction === 'submit' ? ' class="sel"' : '') + '>Submit</button>' +
        '<button type="button" data-baction="reset"' + (buttonAction === 'reset' ? ' class="sel"' : '') + '>Reset</button>' +
        '<button type="button" data-baction="button"' + (buttonAction === 'button' ? ' class="sel"' : '') + '>Button</button>' +
        '</div><span class="hint">Every form needs exactly one Submit button.</span></div>';
    }
    if (CMSFormRenderer.OPTION_TYPES[t]) {
      html += '<div class="field"><label>Options</label><textarea class="input" id="ppOptions" rows="5">' + esc(optionsToText(f.options)) + '</textarea>' +
        '<span class="hint">One per line. Use <code>value | Label</code> for a separate value.</span></div>';
    }
    if (t === 'radio' || t === 'checkboxGroup') {
      var choiceLayout = f.choiceLayout || 'Vertical';
      html += '<div class="field"><label>Layout</label><div class="seg" id="ppLayoutSeg">' +
        '<button type="button" data-layout="Vertical"' + (choiceLayout === 'Vertical' ? ' class="sel"' : '') + '>Vertical</button>' +
        '<button type="button" data-layout="Horizontal"' + (choiceLayout === 'Horizontal' ? ' class="sel"' : '') + '>Horizontal</button>' +
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
    $panel.html(html);
    if (t === 'lookup') fillLookupForms(f);
  }

  // Lookup editors: the Source Form list (cached, current form excluded),
  // then the fields of the chosen form.
  function fillLookupForms(f) {
    function apply(forms) {
      var $select = $('#ppLookupForm');
      if (!$select.length) return;
      $select.html('<option value="">Select form…</option>' + forms
        .filter(function (x) { return String(x.formId) !== String(formId); })
        .map(function (x) {
          var selectedAttr = String(f.lookupFormId) === String(x.formId) ? ' selected' : '';
          return '<option value="' + x.formId + '"' + selectedAttr + '>' + esc(x.title) + ' (' + esc(x.formKey) + ')</option>';
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
    if (!f.lookupFormId) {
      $('#ppLookupField').html('<option value="">Select field…</option>');
      return;
    }
    cmsAjax({
      url: '/api/dynamic-forms/' + f.lookupFormId, method: 'GET', fallbackMsg: 'Could not load fields.',
      success: function (src) {
        var $select = $('#ppLookupField');
        if (!$select.length) return;
        $select.html('<option value="">Select field…</option>' + (src.fields || []).map(function (x) {
          var selectedAttr = f.lookupFieldKey === x.fieldKey ? ' selected' : '';
          return '<option value="' + esc(x.fieldKey) + '"' + selectedAttr + '>' + esc(x.label) + ' (' + esc(x.fieldKey) + ')</option>';
        }).join(''));
      },
      error: function () { return true; }
    });
  }

  // Empty text -> null, otherwise a number (for min/max editors).
  function numOrNull(value) {
    value = $.trim(value || '');
    return value === '' ? null : Number(value);
  }

  // Every Properties input writes straight back into the selected field
  // and re-renders the canvas, so the preview always matches the panel.
  $('#dfbProps').on('input change', 'input, textarea, select', function () {
    var f = fields[selected];
    if (!f) return;
    var $input = $(this);
    // Grid column rows and mini-rows (attributes / rules) first: they
    // are identified by class, not by id.
    if ($input.hasClass('pp-col-key')) { f.gridColumns[Number($input.data('ci'))].key = slug($input.val()); renderCanvas(); return; }
    if ($input.hasClass('pp-col-label')) { f.gridColumns[Number($input.data('ci'))].label = $input.val(); renderCanvas(); return; }
    if ($input.hasClass('pp-col-options')) { f.gridColumns[Number($input.data('ci'))].options = textToOptions($input.val()); renderCanvas(); return; }
    if ($input.hasClass('pp-col-type')) { f.gridColumns[Number($input.data('ci'))].type = $input.val(); renderCanvas(); renderProps(); return; }
    if ($input.hasClass('pp-attr-name')) { f.customAttributes[Number($input.data('ai'))].name = $.trim($input.val()); return; }
    if ($input.hasClass('pp-attr-value')) { f.customAttributes[Number($input.data('ai'))].value = $input.val(); return; }
    if ($input.hasClass('pp-rule-pattern')) { f.validationRules[Number($input.data('ri'))].pattern = $.trim($input.val()); return; }
    if ($input.hasClass('pp-rule-message')) { f.validationRules[Number($input.data('ri'))].message = $input.val(); return; }
    var id = this.id;
    if (id === 'ppLabel') f.label = $input.val();
    else if (id === 'ppKey') f.fieldKey = slug($input.val()) || f.fieldKey;
    else if (id === 'ppSpan') f.columnSpan = Number($input.val());
    else if (id === 'ppRequired') f.isRequired = $input.is(':checked');
    else if (id === 'ppShowBorder') f.showBorder = $input.is(':checked');
    else if (id === 'ppShowDivider') f.showDivider = $input.is(':checked');
    else if (id === 'ppPlaceholder') f.placeholder = $input.val();
    else if (id === 'ppDefault') f.defaultValue = $input.val();
    else if (id === 'ppHelp') f.helpText = $input.val();
    else if (id === 'ppOptions') f.options = textToOptions($input.val());
    else if (id === 'ppMinLen') f.minLength = numOrNull($input.val());
    else if (id === 'ppMaxLen') f.maxLength = numOrNull($input.val());
    else if (id === 'ppMinVal') f.minValue = numOrNull($input.val());
    else if (id === 'ppMaxVal') f.maxValue = numOrNull($input.val());
    else if (id === 'ppAccept') f.accept = $input.val();
    else if (id === 'ppRegex') f.regexPattern = $input.val();
    else if (id === 'ppRegexMsg') f.validationMessage = $input.val();
    else if (id === 'ppLookupForm') {
      f.lookupFormId = $input.val() ? Number($input.val()) : null;
      f.lookupFieldKey = '';
      renderCanvas();
      fillLookupFields(f);
      return;
    }
    else if (id === 'ppLookupField') f.lookupFieldKey = $input.val();
    else if (id === 'ppCssClass') f.cssClass = $input.val();
    else if (id === 'ppCustomId') f.customId = $input.val();
    else if (id === 'ppInputMask') f.inputMask = $input.val();
    else if (id === 'ppInfoText') f.infoText = $input.val();
    else if (id === 'ppShowInfo') f.showInfoIcon = $input.is(':checked');
    else if (id === 'ppCustomJs') f.customJs = $input.val();
    else return; // unknown control: change nothing, re-render nothing
    renderCanvas();
  });

  $('#dfbProps').on('click', '#ppDel', function () { deleteField(selected); });
  $('#dfbProps').on('click', '#ppDup', function () { duplicateField(selected); });
  $('#dfbProps').on('click', '#ppBtnSeg button', function () {
    var f = fields[selected];
    if (!f) return;
    f.buttonAction = $(this).data('baction');
    renderProps();
    renderCanvas();
  });
  $('#dfbProps').on('click', '#ppAddCol', function () {
    var f = fields[selected];
    if (!f || f.fieldType !== 'grid') return;
    var n = (f.gridColumns || []).length + 1;
    f.gridColumns.push({ key: 'column-' + n, label: 'Column ' + n, type: 'text', options: [] });
    renderProps();
    renderCanvas();
  });
  $('#dfbProps').on('click', '[data-col-del]', function () {
    var f = fields[selected];
    if (!f) return;
    f.gridColumns.splice(Number($(this).data('col-del')), 1);
    renderProps();
    renderCanvas();
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
  $('#dfbProps').on('click', '#ppLayoutSeg button', function () {
    var f = fields[selected];
    if (!f) return;
    f.choiceLayout = $(this).data('layout');
    renderCanvas();
  });

  // Delete a field. A section's children are not lost: they move up to
  // the deleted section's parent.
  function deleteField(i) {
    if (i < 0 || i >= fields.length) return;
    var removed = fields[i];
    if (isSection(removed)) {
      fields.forEach(function (child) {
        if ((child.parentKey || null) === removed.fieldKey) child.parentKey = removed.parentKey || null;
      });
    }
    fields.splice(i, 1);
    selected = -1;
    renderCanvas();
    renderProps();
  }

  // Copy a field right after itself, with a fresh key and " (copy)".
  function duplicateField(i) {
    if (i < 0 || i >= fields.length) return;
    var copy = JSON.parse(JSON.stringify(fields[i]));
    copy.fieldKey = uniqueKey(copy.fieldKey + '-copy');
    copy.label = copy.label + ' (copy)';
    fields.splice(i + 1, 0, copy);
    selectField(i + 1);
  }

  /* ------------------------------------------------------------------
     Canvas clicks and drag & drop.

     Three kinds of drag exist, tracked in `dragState`:
       new     — a palette item being added (copy)
       move    — an existing field card being moved
       section — a whole section box being reordered among its siblings
     Drops land in a "zone": a column zone or a span-grid area. The
     insert position inside a zone is the flat array index of the first
     card below the pointer, or just past the last card.
     ------------------------------------------------------------------ */

  // Click a card (or a section bar) to select it. Clicks on the small
  // action buttons are handled by their own handlers below.
  $('#dfbGrid').on('click', '.dfb-card', function (e) {
    if ($(e.target).closest('[data-del],[data-dup]').length) return;
    selectField(Number($(this).data('index')));
  });
  $('#dfbGrid').on('click', '[data-del]', function (e) {
    e.stopPropagation();
    deleteField(Number($(this).data('del')));
  });
  $('#dfbGrid').on('click', '[data-dup]', function (e) {
    e.stopPropagation();
    duplicateField(Number($(this).data('dup')));
  });
  $('#dfbGrid').on('click', '.dfb-section-bar', function (e) {
    if ($(e.target).closest('[data-del],[data-dup],[data-seclayout],[data-secdrag]').length) return;
    selectField(Number($(this).closest('.dfb-section-box').data('secbox')));
  });
  // Layout buttons live inside section bars, so they are caught at the
  // document level (the bar's own click handler ignores them).
  $(document).on('click', '[data-seclayout]', function (e) {
    e.stopPropagation();
    var secIdx = Number($(this).data('secidx'));
    if (isNaN(secIdx) || !fields[secIdx]) secIdx = selected;
    var value = $(this).data('seclayout');
    applySectionLayout(secIdx, value === '' || value == null ? null : Number(value));
    selectField(secIdx);
  });

  // Delete key removes the selected field, unless the user is typing.
  $(document).on('keydown', function (e) {
    if (e.key !== 'Delete' || selected < 0) return;
    var target = e.target;
    if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' ||
        target.tagName === 'SELECT' || target.isContentEditable)) return;
    deleteField(selected);
  });

  // Drop-zone highlight: only one zone is "hot" at a time.
  var hotEl = null;
  function setHot(el) {
    if (hotEl === el) return;
    clearHot();
    hotEl = el || null;
    if (hotEl) hotEl.classList.add('dfb-hot');
  }
  function clearHot() {
    if (hotEl) { hotEl.classList.remove('dfb-hot'); hotEl = null; }
  }

  // Flat insert index for a span-grid area: the first card whose middle
  // is below the pointer, otherwise just past the last card, otherwise
  // where the area itself sits in its parent level.
  function areaInsertIndex($area, y) {
    var $cards = $area.find('.dfb-card').filter(function () {
      return $(this).closest('.dfb-area')[0] === $area[0];
    });
    var insertAt = null;
    $cards.each(function () {
      var rect = this.getBoundingClientRect();
      if (insertAt === null && y < rect.top + rect.height / 2) insertAt = Number($(this).data('index'));
    });
    if (insertAt !== null) return insertAt;
    if ($cards.length) return Number($cards.last().data('index')) + 1;
    var parentKey = $area.data('parent') || null;
    if (parentKey) {
      var secIdx = fields.findIndex(function (f) { return f.fieldKey === parentKey; });
      return secIdx >= 0 ? secIdx + 1 : fields.length;
    }
    var firstSection = fields.findIndex(function (f) {
      return (f.parentKey || null) === null && isSection(f);
    });
    return firstSection >= 0 ? firstSection : fields.length;
  }

  // Flat insert index for one column of a column-layout section. Cards
  // and nested section boxes both count, by their flat index.
  function columnInsertIndex(secIdx, col, y) {
    var $zone = $('.dfb-col-zone[data-secidx="' + secIdx + '"][data-col="' + col + '"]');
    var items = [];
    var before = null;
    $zone.children().each(function () {
      var $child = $(this);
      var flat = null;
      if ($child.hasClass('dfb-card')) flat = Number($child.data('index'));
      else if ($child.hasClass('dfb-nested-box')) flat = Number($child.find('[data-secbox]').first().data('secbox'));
      if (flat === null || isNaN(flat)) return;
      items.push(flat);
      var rect = this.getBoundingClientRect();
      if (before === null && y < rect.top + rect.height / 2) before = flat;
    });
    if (before !== null) return before;
    if (items.length) return items[items.length - 1] + 1;
    // Empty column: before the first child of a later column, otherwise
    // after the section's last child, otherwise right after the section.
    var kids = childrenIdx(fields[secIdx].fieldKey);
    for (var k = 0; k < kids.length; k++) {
      if ((fields[kids[k]].columnIndex || 0) > col) return kids[k];
    }
    return kids.length ? kids[kids.length - 1] + 1 : secIdx + 1;
  }

  // Place a field at a flat index inside a parent (section key or null)
  // and column (column number, or null for span-grid areas). For a new
  // palette field this creates it; for a moved field it relocates it.
  function placeField(idx, colIdx, parentKey) {
    parentKey = parentKey || null;
    if (dragState.kind === 'new') {
      var fresh = newField(dragState.type, dragState.preset);
      fresh.parentKey = parentKey;
      fresh.columnIndex = parentKey ? colIdx : null;
      fields.splice(idx, 0, fresh);
      selectField(idx);
      return;
    }
    var from = dragState.index;
    if (from === null || from === undefined || from === idx || from === idx - 1) {
      renderCanvas();
      return;
    }
    var item = fields.splice(from, 1)[0];
    if (from < idx) idx--;
    // A section can never land inside itself or one of its own sections.
    if (isSection(item) && parentKey && descendantKeys(item.fieldKey).indexOf(parentKey) >= 0) {
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

  // Reorder a section box among its siblings (same parent). Only the
  // section's own row moves — its fields follow by key.
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
      var $child = $(this);
      var boxIdx = Number($child.is('[data-secbox]')
        ? $child.data('secbox')
        : $child.find('[data-secbox]').first().data('secbox'));
      if (isNaN(boxIdx) || boxIdx === from) return;
      var rect = this.getBoundingClientRect();
      if (y < rect.top + rect.height / 2) targetObj = fields[boxIdx];
    });
    fields.splice(from, 1);
    var ins;
    if (targetObj) {
      ins = fields.indexOf(targetObj);
    } else {
      var siblings = fields.filter(function (f) {
        return isSection(f) && (f.parentKey || null) === parentKey;
      });
      ins = siblings.length ? fields.indexOf(siblings[siblings.length - 1]) + 1 : fields.length;
    }
    fields.splice(ins, 0, item);
    selectField(ins);
  }

  // Palette: drag to copy a new field, click to append one at the end.
  $('#dfbPalette').on('dragstart', '.dfb-pal-item', function (e) {
    var preset = $(this).attr('data-preset');
    dragState = { kind: 'new', type: $(this).data('ptype'), preset: preset === undefined ? undefined : Number(preset) };
    e.originalEvent.dataTransfer.effectAllowed = 'copy';
    e.originalEvent.dataTransfer.setData('text/plain', 'dfb');
  });
  $('#dfbPalette').on('click', '.dfb-pal-item', function () {
    var preset = $(this).attr('data-preset');
    fields.push(newField($(this).data('ptype'), preset === undefined ? undefined : Number(preset)));
    selectField(fields.length - 1);
  });

  // Canvas: drag a field card, or a section header.
  $('#dfbGrid').on('dragstart', '[data-drag]', function (e) {
    dragState = { kind: 'move', index: Number($(this).data('drag')) };
    e.originalEvent.dataTransfer.effectAllowed = 'move';
    e.originalEvent.dataTransfer.setData('text/plain', 'dfb');
  });
  $('#dfbGrid').on('dragstart', '[data-secdrag]', function (e) {
    dragState = { kind: 'section', index: Number($(this).data('secdrag')) };
    e.originalEvent.dataTransfer.effectAllowed = 'move';
    e.originalEvent.dataTransfer.setData('text/plain', 'dfb');
  });

  // Find the drop zone for a drag event: first the zone directly under
  // the pointer; if the pointer is on a dead spot (empty-state text,
  // gaps, section padding), fall back to the nearest zone by distance,
  // so a drop anywhere on the canvas still lands somewhere.
  function resolveDropZone(e) {
    var $zone = $(e.target).closest('.dfb-col-zone, .dfb-area');
    if ($zone.length) return $zone[0];
    var x = e.originalEvent.clientX;
    var y = e.originalEvent.clientY;
    var best = null;
    var bestDist = Infinity;
    $('#dfbCanvas .dfb-col-zone, #dfbCanvas .dfb-area').each(function () {
      var rect = this.getBoundingClientRect();
      var dx = x < rect.left ? rect.left - x : (x > rect.right ? x - rect.right : 0);
      var dy = y < rect.top ? rect.top - y : (y > rect.bottom ? y - rect.bottom : 0);
      if (dx + dy < bestDist) { bestDist = dx + dy; best = this; }
    });
    return best;
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
    if (!$(e.target).closest('#dfbCanvas').length ||
        (e.relatedTarget && !$.contains(this, e.relatedTarget))) {
      $(this).removeClass('dfb-over');
      clearHot();
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
          var sectionIdx = Number($zone.data('secidx'));
          placeField(
            columnInsertIndex(sectionIdx, Number($zone.data('col')), y),
            Number($zone.data('col')),
            fields[sectionIdx].fieldKey
          );
        } else {
          placeField(areaInsertIndex($zone, y), null, $zone.data('parent') || null);
        }
      } else {
        // No zones on the canvas at all — append at the end.
        placeField(fields.length, null, null);
      }
    }
    clearHot();
    dragState = null;
  });
  $(document).on('dragend', function () {
    dragState = null;
    clearHot();
    $('#dfbCanvas').removeClass('dfb-over');
  });

  /* ------------------------------------------------------------------
     Resizable panes: drag the gutters between Fields / Canvas /
     Properties. Widths persist in localStorage across reloads.
     ------------------------------------------------------------------ */
  (function initPaneResize() {
    var layout = document.querySelector('.dfb-layout');
    if (!layout) return;
    try {
      var savedPal = localStorage.getItem('dfbPalW');
      var savedProps = localStorage.getItem('dfbPropsW');
      if (savedPal) layout.style.setProperty('--pal-w', savedPal + 'px');
      if (savedProps) layout.style.setProperty('--props-w', savedProps + 'px');
    } catch (err) { /* storage unavailable: keep default widths */ }
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
          try { localStorage.setItem(side === 'left' ? 'dfbPalW' : 'dfbPropsW', String(Math.round(w))); }
          catch (err) { /* ignore */ }
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

  /* ------------------------------------------------------------------
     Form settings (toolbar), loading and saving
     ------------------------------------------------------------------ */
  $('#dfbDescToggle').on('click', function () {
    var $row = $('#dfbDescRow');
    $row.prop('hidden', !$row.prop('hidden'));
    if (!$row.prop('hidden')) $('#dfbDesc').focus();
  });
  // While the form key was never typed by hand, it follows the title.
  $('#dfbTitle').on('input', function () {
    var $key = $('#dfbKey');
    if (formId === '' && !$key.data('touched')) $key.val(slug($(this).val()));
  });
  $('#dfbKey').on('input', function () { $(this).data('touched', true); });

  // Load the form for editing, or start empty for a new form.
  function loadForm() {
    if (!formId) {
      fields = [];
      renderPalette();
      renderCanvas();
      renderProps();
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
            customAttributes: (x.customAttributes || []).map(function (a) {
              return { name: a.name || '', value: a.value || '' };
            }),
            validationRules: (x.validationRules || []).map(function (r) {
              return { pattern: r.pattern || '', message: r.message || '' };
            }),
            inputMask: x.inputMask || '', showInfoIcon: !!x.showInfoIcon, infoText: x.infoText || '',
            parentKey: x.parentKey || null,
            showBorder: x.showBorder === undefined ? null : x.showBorder,
            showDivider: x.showDivider === undefined ? null : x.showDivider,
            sectionColumns: x.sectionColumns == null ? null : x.sectionColumns,
            columnIndex: x.columnIndex == null ? null : x.columnIndex,
            columnSpan: x.columnSpan || 6
          };
        });
        renderPalette();
        renderCanvas();
        renderProps();
      }
    });
  }

  // The save payload: the same field shape the API expects, with
  // type-specific values cleared when they do not apply to the type.
  function savePayload() {
    return {
      formKey: slug($('#dfbKey').val()),
      title: $.trim($('#dfbTitle').val()),
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
          parentKey: f.parentKey || null, showBorder: f.showBorder, showDivider: f.showDivider,
          customJs: f.customJs || null, cssClass: f.cssClass || null, customId: f.customId || null,
          customAttributes: (f.customAttributes || []).filter(function (a) { return a.name; }),
          validationRules: (f.validationRules || []).filter(function (r) { return r.pattern; }),
          inputMask: f.inputMask || null, showInfoIcon: !!f.showInfoIcon, infoText: f.infoText || null,
          sectionColumns: f.fieldType === 'section' ? (f.sectionColumns || null) : null,
          columnIndex: (f.columnIndex == null ? null : f.columnIndex),
          columnSpan: (f.fieldType === 'section' || f.fieldType === 'hidden') ? 12 : (f.columnSpan || 6),
          sortOrder: i
        };
      })
    };
  }

  $('#dfbSaveBtn').on('click', function () {
    var title = $.trim($('#dfbTitle').val());
    var key = slug($('#dfbKey').val());
    if (!title) { CMS.toast('Form title is required.', 'error'); $('#dfbTitle').focus(); return; }
    if (!key) { CMS.toast('Form key is required.', 'error'); $('#dfbKey').focus(); return; }
    if (!fields.length) { CMS.toast('Add at least one field.', 'error'); return; }
    var submitCount = fields.filter(function (f) {
      return f.fieldType === 'button' && f.buttonAction === 'submit';
    }).length;
    if (submitCount !== 1) {
      CMS.toast('The form must contain exactly one Submit button (found ' + submitCount + '). Add a Button field and set its type to Submit.', 'error');
      return;
    }
    for (var gi = 0; gi < fields.length; gi++) {
      if (fields[gi].fieldType === 'grid' && !(fields[gi].gridColumns || []).length) {
        CMS.toast('Grid "' + fields[gi].label + '" needs at least one column.', 'error');
        return;
      }
      if (fields[gi].fieldType === 'lookup' && (!fields[gi].lookupFormId || !fields[gi].lookupFieldKey)) {
        CMS.toast('Lookup "' + fields[gi].label + '" needs a source form and source field.', 'error');
        return;
      }
    }
    cmsAjax({
      url: formId ? '/api/dynamic-forms/' + formId : '/api/dynamic-forms',
      method: formId ? 'PUT' : 'POST', json: true, data: savePayload(),
      fallbackMsg: 'Could not save form.',
      success: function (res) {
        CMS.toast('Form saved.', 'success');
        if (!formId && res && res.formId) {
          window.location.href = '/DynamicForms/Builder/' + res.formId;
        } else {
          selected = -1;
          loadForm();
        }
      }
    });
  });

  // Preview the current in-memory form (unsaved changes included) in a
  // modal, so the user can verify it before saving.
  $('#dfbPreviewBtn').on('click', function () {
    if (!fields.length) { CMS.toast('Add at least one field to preview.', 'error'); return; }
    var formDef = {
      title: $.trim($('#dfbTitle').val()) || 'Untitled Form',
      description: $.trim($('#dfbDesc').val()),
      isMultiStep: $('#dfbMultiStep').is(':checked'),
      fields: fields.map(function (f, i) {
        var copy = JSON.parse(JSON.stringify(f));
        copy.sortOrder = i;
        return copy;
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
