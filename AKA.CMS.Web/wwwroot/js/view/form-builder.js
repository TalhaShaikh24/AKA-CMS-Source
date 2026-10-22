/* Dynamic Form Builder — palette (drag & drop), grid canvas, properties panel.
   State lives in `fields[]`; save sends the whole definition to /api/dynamic-forms. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();

  var PALETTE = [
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
    { group: 'Layout' },
    { type: 'section', label: 'Section', icon: '▤' },
    { type: 'heading', label: 'Heading', icon: 'H' },
    { type: 'paragraph', label: 'Paragraph Text', icon: '≡' },
    { group: 'Actions' },
    { type: 'button', label: 'Button', icon: '▸' }
  ];
  var TYPE_LABELS = {};
  PALETTE.forEach(function (p) { TYPE_LABELS[p.type] = p.label; });
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

  function newField(type) {
    var label = TYPE_LABELS[type] || 'Field';
    var f = {
      fieldKey: uniqueKey(slug(label)), label: label, fieldType: type,
      placeholder: '', helpText: '', isRequired: false, defaultValue: '',
      options: [], minLength: null, maxLength: null, minValue: null, maxValue: null,
      accept: '', choiceLayout: 'Vertical',
      buttonAction: null, regexPattern: '', validationMessage: '',
      lookupFormId: null, lookupFieldKey: '', gridColumns: [],
      columnSpan: (type === 'heading' || type === 'paragraph') ? 12 : 6
    };
    if (CMSFormRenderer.OPTION_TYPES[type]) {
      f.options = [ { value: 'option-1', label: 'Option 1' }, { value: 'option-2', label: 'Option 2' } ];
    }
    if (type === 'section') { f.label = 'New Section'; f.columnSpan = 12; }
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
      return '<div class="dfb-pal-item" draggable="true" data-ptype="' + p.type + '">' +
        '<span class="dfb-pal-icon">' + esc(p.icon) + '</span><span>' + esc(p.label) + '</span></div>';
    }).join(''));
  }

  /* ---------------- canvas ---------------- */
  function renderCanvas() {
    var $grid = $('#dfbGrid');
    $('#dfbEmpty').toggle(fields.length === 0);
    $('#dfbFieldCount').text(fields.length ? fields.length + ' field' + (fields.length === 1 ? '' : 's') : '');
    $grid.html(fields.map(function (f, i) {
      var preview = CMSFormRenderer.fieldHtml(f, true);
      return '<div class="dfb-card' + (i === selected ? ' sel' : '') + '" data-index="' + i + '"' +
          ' style="grid-column: span ' + (f.columnSpan || 6) + '">' +
        '<div class="dfb-card-bar">' +
          '<span class="dfb-drag" draggable="true" data-drag="' + i + '" title="Drag to reorder">⠿</span>' +
          '<span class="dfb-card-type">' + esc(TYPE_LABELS[f.fieldType] || f.fieldType) + '</span>' +
          '<span class="dfb-card-actions">' +
            '<button type="button" data-dup="' + i + '" title="Duplicate">⧉</button>' +
            '<button type="button" data-del="' + i + '" title="Delete">✕</button>' +
          '</span>' +
        '</div>' +
        '<div class="dfb-card-body">' + preview + '</div>' +
      '</div>';
    }).join(''));
    // The renderer wraps fields in its own grid cell — unwrap one level for the card body.
    $grid.find('.dfb-card-body > .dfb-cell, .dfb-card-body > .field').css('grid-column', 'auto');
  }

  function selectField(i) {
    selected = i;
    renderCanvas();
    renderProps();
  }

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
  $('#dfbProps').on('click', '#ppLayoutSeg button', function () {
    var f = fields[selected];
    if (!f) return;
    f.choiceLayout = $(this).data('layout');
    renderCanvas();
  });

  function deleteField(i) {
    if (i < 0 || i >= fields.length) return;
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

  function dropIndexFor(e) {
    // Insert position = first card whose vertical middle is below the cursor.
    var y = e.originalEvent.clientY;
    var idx = fields.length;
    $('#dfbGrid .dfb-card').each(function (i) {
      var r = this.getBoundingClientRect();
      if (y < r.top + r.height / 2) { idx = Math.min(idx, i); }
    });
    return idx;
  }

  /* palette drag + click */
  $('#dfbPalette').on('dragstart', '.dfb-pal-item', function (e) {
    dragState = { kind: 'new', type: $(this).data('ptype') };
    e.originalEvent.dataTransfer.effectAllowed = 'copy';
    e.originalEvent.dataTransfer.setData('text/plain', 'dfb');
  });
  $('#dfbPalette').on('click', '.dfb-pal-item', function () {
    fields.push(newField($(this).data('ptype')));
    selectField(fields.length - 1);
  });

  /* canvas reorder drag */
  $('#dfbGrid').on('dragstart', '[data-drag]', function (e) {
    dragState = { kind: 'move', index: Number($(this).data('drag')) };
    e.originalEvent.dataTransfer.effectAllowed = 'move';
    e.originalEvent.dataTransfer.setData('text/plain', 'dfb');
  });

  $('#dfbCanvas').on('dragover', function (e) {
    if (!dragState) return;
    e.preventDefault();
    e.originalEvent.dataTransfer.dropEffect = dragState.kind === 'new' ? 'copy' : 'move';
    $(this).addClass('dfb-over');
  });
  $('#dfbCanvas').on('dragleave', function () { $(this).removeClass('dfb-over'); });
  $('#dfbCanvas').on('drop', function (e) {
    e.preventDefault();
    $(this).removeClass('dfb-over');
    if (!dragState) return;
    var idx = dropIndexFor(e);
    if (dragState.kind === 'new') {
      fields.splice(idx, 0, newField(dragState.type));
      selectField(idx);
    } else {
      var from = dragState.index;
      var item = fields.splice(from, 1)[0];
      if (from < idx) idx--;
      fields.splice(idx, 0, item);
      selectField(idx);
    }
    dragState = null;
  });
  $(document).on('dragend', function () { dragState = null; $('#dfbCanvas').removeClass('dfb-over'); });

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
      // A new form starts with its (required) Submit button already in place.
      fields = [newField('button')];
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
