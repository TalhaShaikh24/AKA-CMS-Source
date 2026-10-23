/* Dynamic Form Renderer — renders a saved form definition with the app
   theme (.field / .input / .select2 / .check-row). Supports sections,
   multi-step (wizard) forms, hidden inputs, buttons, grid/table inputs,
   SharePoint-style lookups and custom regex validation.
   Used by the Render page and the builder's live preview.
   Usage: CMSFormRenderer.render($container, formDetail, { preview: true }) */
window.CMSFormRenderer = (function () {
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  var OPTION_TYPES = { select: 1, multiselect: 1, radio: 1, checkboxGroup: 1 };
  var STATIC_TYPES = { heading: 1, paragraph: 1, section: 1, button: 1 };

  function labelHtml(f) {
    return '<label>' + esc(f.label) + (f.isRequired ? ' <span class="req">*</span>' : '') + '</label>';
  }

  function helpHtml(f) {
    return f.helpText ? '<span class="hint">' + esc(f.helpText) + '</span>' : '';
  }

  function optionsHtml(f, selected) {
    return (f.options || []).map(function (o) {
      var sel = selected != null && String(selected) === String(o.value) ? ' selected' : '';
      return '<option value="' + esc(o.value) + '"' + sel + '>' + esc(o.label) + '</option>';
    }).join('');
  }

  /* ---------------- grid / table ---------------- */
  function gridCellHtml(c, dis) {
    var col = ' data-col="' + esc(c.key) + '"';
    if (c.type === 'select') {
      return '<select class="input dfb-grid-cell"' + col + dis + '><option value="">Select…</option>' +
        (c.options || []).map(function (o) {
          return '<option value="' + esc(o.value) + '">' + esc(o.label) + '</option>';
        }).join('') + '</select>';
    }
    var t = c.type === 'number' ? 'number' : (c.type === 'date' ? 'date' : 'text');
    return '<input class="input dfb-grid-cell" type="' + t + '"' + col + dis + '>';
  }

  function gridRowHtml(f, preview) {
    var dis = preview ? ' disabled' : '';
    var cells = (f.gridColumns || []).map(function (c) { return '<td>' + gridCellHtml(c, dis) + '</td>'; }).join('');
    var act = preview ? '<td class="dfb-grid-act"></td>'
      : '<td class="dfb-grid-act"><button type="button" class="dfb-grid-del" title="Remove row">✕</button></td>';
    return '<tr>' + cells + act + '</tr>';
  }

  function fieldHtml(f, preview) {
    var dis = preview ? ' disabled' : '';
    var key = esc(f.fieldKey);
    var span = ' style="grid-column: span ' + (f.columnSpan || 6) + '"';
    var inner = '';

    switch (f.fieldType) {
      case 'heading':
        return '<div class="dfb-cell dfb-static"' + span + '><h3 class="dfb-heading">' + esc(f.label) + '</h3>' + helpHtml(f) + '</div>';
      case 'paragraph':
        return '<div class="dfb-cell dfb-static"' + span + '><p class="dfb-paragraph">' + esc(f.label) + '</p></div>';
      case 'section':
        // In a rendered form, sections are structural (see render()); this
        // banner is what the builder canvas shows for a section field.
        return '<div class="dfb-cell dfb-section-banner" style="grid-column: span 12">' +
          '<strong>' + esc(f.label) + '</strong>' + (f.helpText ? '<span class="hint">' + esc(f.helpText) + '</span>' : '') + '</div>';
      case 'hidden':
        if (preview) {
          return '<div class="dfb-cell dfb-hidden-chip" style="grid-column: span 12">' +
            'Hidden · ' + key + ' = &quot;' + esc(f.defaultValue || '') + '&quot;</div>';
        }
        return '<input type="hidden" name="' + key + '" value="' + esc(f.defaultValue || '') + '">';
      case 'button': {
        var act = f.buttonAction || 'button';
        if (act !== 'submit' && act !== 'reset' && act !== 'button') act = 'button';
        inner = '<button type="' + act + '" class="' + (act === 'submit' ? 'btn btn-primary' : 'btn btn-ghost') + '"' + dis + '>' +
          esc(f.label) + '</button>' + helpHtml(f);
        return '<div class="field dfb-cell dfb-btn-cell"' + span + '>' + inner + '</div>';
      }
      case 'grid': {
        var cols = (f.gridColumns || []).map(function (c) { return '<th>' + esc(c.label) + '</th>'; }).join('') + '<th class="dfb-grid-act"></th>';
        inner = labelHtml(f) +
          '<div class="dfb-grid-wrap" data-grid-field="' + key + '">' +
            '<table class="dfb-grid-table"><thead><tr>' + cols + '</tr></thead><tbody>' +
            gridRowHtml(f, preview) + '</tbody></table>' +
            (preview ? '' : '<button type="button" class="btn btn-ghost btn-sm dfb-grid-add">+ Add row</button>') +
          '</div>' + helpHtml(f);
        break;
      }
      case 'lookup':
        inner = labelHtml(f) +
          '<select class="input select2" name="' + key + '"' +
          ' data-lookup-form="' + (f.lookupFormId || '') + '"' +
          ' data-lookup-field="' + esc(f.lookupFieldKey || '') + '"' +
          ' data-default="' + esc(f.defaultValue || '') + '"' + dis + '>' +
          '<option value="">' + esc(f.placeholder || 'Select…') + '</option></select>' + helpHtml(f);
        break;
      case 'textarea':
        inner = labelHtml(f) +
          '<textarea class="input" name="' + key + '" rows="3" placeholder="' + esc(f.placeholder || '') + '"' + dis + '>' +
          esc(f.defaultValue || '') + '</textarea>' + helpHtml(f);
        break;
      case 'select':
        inner = labelHtml(f) +
          '<select class="input select2" name="' + key + '"' + dis + '>' +
          '<option value="">' + esc(f.placeholder || 'Select…') + '</option>' +
          optionsHtml(f, f.defaultValue) + '</select>' + helpHtml(f);
        break;
      case 'multiselect':
        inner = labelHtml(f) +
          '<select class="input select2" name="' + key + '" multiple' + dis + '>' +
          optionsHtml(f, null) + '</select>' + helpHtml(f);
        break;
      case 'radio':
        inner = labelHtml(f) + '<div class="dfb-choices' + (f.choiceLayout === 'Horizontal' ? ' dfb-choices-h' : '') + '">' + (f.options || []).map(function (o) {
          var chk = f.defaultValue != null && String(f.defaultValue) === String(o.value) ? ' checked' : '';
          return '<label class="check-row"><input type="radio" name="' + key + '" value="' + esc(o.value) + '"' + chk + dis + '>' +
            '<span class="check-label">' + esc(o.label) + '</span></label>';
        }).join('') + '</div>' + helpHtml(f);
        break;
      case 'checkboxGroup':
        inner = labelHtml(f) + '<div class="dfb-choices' + (f.choiceLayout === 'Horizontal' ? ' dfb-choices-h' : '') + '">' + (f.options || []).map(function (o) {
          return '<label class="check-row"><input type="checkbox" name="' + key + '" value="' + esc(o.value) + '"' + dis + '>' +
            '<span class="check-label">' + esc(o.label) + '</span></label>';
        }).join('') + '</div>' + helpHtml(f);
        break;
      case 'checkbox':
        inner = '<label class="check-row"><input type="checkbox" name="' + key + '"' +
          (f.defaultValue === 'true' ? ' checked' : '') + dis + '>' +
          '<span class="check-label">' + esc(f.label) + (f.isRequired ? ' <span class="req">*</span>' : '') + '</span></label>' + helpHtml(f);
        break;
      case 'file':
        inner = labelHtml(f) +
          '<input class="input" type="file" name="' + key + '"' +
          (f.accept ? ' accept="' + esc(f.accept) + '"' : '') + dis + '>' + helpHtml(f);
        break;
      default: { // text, email, number, password, date, time, datetime
        var typeMap = { text: 'text', email: 'email', number: 'number', password: 'password',
                        date: 'date', time: 'time', datetime: 'datetime-local' };
        var attrs = '';
        if (f.fieldType === 'number') {
          if (f.minValue != null) attrs += ' min="' + f.minValue + '"';
          if (f.maxValue != null) attrs += ' max="' + f.maxValue + '"';
        }
        if (f.minLength != null) attrs += ' minlength="' + f.minLength + '"';
        if (f.maxLength != null) attrs += ' maxlength="' + f.maxLength + '"';
        inner = labelHtml(f) +
          '<input class="input" type="' + (typeMap[f.fieldType] || 'text') + '" name="' + key + '"' +
          ' placeholder="' + esc(f.placeholder || '') + '" value="' + esc(f.defaultValue || '') + '"' +
          attrs + dis + '>' + helpHtml(f);
        break;
      }
    }
    return '<div class="field dfb-cell"' + span + '>' + inner + '</div>';
  }

  /* Group sorted fields by section: a section field starts a new group. */
  function groupFields(fields) {
    var groups = [{ title: null, helpText: null, section: null, fields: [] }];
    fields.forEach(function (f) {
      if (f.fieldType === 'section') groups.push({ title: f.label, helpText: f.helpText, section: f, fields: [] });
      else groups[groups.length - 1].fields.push(f);
    });
    if (groups.length > 1 && groups[0].title === null && !groups[0].fields.length) groups.shift();
    return groups;
  }

  function sectionHeadHtml(g) {
    if (g.title == null) return '';
    return '<div class="dfb-section-head"><h3>' + esc(g.title) + '</h3>' +
      (g.helpText ? '<p class="hint">' + esc(g.helpText) + '</p>' : '') + '</div>';
  }

  function gridHtml(fields, preview) {
    return '<div class="dfb-grid">' + fields.map(function (f) { return fieldHtml(f, preview); }).join('') + '</div>';
  }

  /* Elementor-style columns: fields stack inside their column (full width),
     grouped by columnIndex. Used when the section has sectionColumns set. */
  function columnsHtml(g, preview) {
    var n = Math.min(4, Math.max(1, g.section.sectionColumns || 1));
    var buckets = [];
    for (var i = 0; i < n; i++) buckets.push([]);
    g.fields.forEach(function (f) {
      var ci = f.columnIndex == null ? 0 : Math.min(n - 1, Math.max(0, f.columnIndex));
      buckets[ci].push(f);
    });
    return '<div class="dfb-cols" style="--cols:' + n + '">' + buckets.map(function (bucket) {
      return '<div class="dfb-col">' + bucket.map(function (f) {
        var clone = Object.assign({}, f, { columnSpan: 12 });
        return fieldHtml(clone, preview);
      }).join('') + '</div>';
    }).join('') + '</div>';
  }

  /* One group (section or leading fields) as HTML — used by normal and
     wizard rendering alike. */
  function groupHtml(g, preview) {
    var body = (g.section && g.section.sectionColumns) ? columnsHtml(g, preview) : gridHtml(g.fields, preview);
    if (g.title == null) return body;
    return '<section class="dfb-section">' + sectionHeadHtml(g) + body + '</section>';
  }

  function render($container, form, opts) {
    opts = opts || {};
    var preview = !!opts.preview;
    var fields = (form.fields || []).slice().sort(function (a, b) { return (a.sortOrder || 0) - (b.sortOrder || 0); });
    var groups = groupFields(fields);
    var html = '';

    if (form.isMultiStep && groups.length > 1) {
      html = '<div class="dfb-wizard">' +
        '<div class="dfb-wiz-progress"><span class="dfb-wiz-label"></span>' +
        '<div class="dfb-wiz-bar"><i></i></div></div>' +
        groups.map(function (g, i) {
          return '<div class="dfb-step" data-step="' + i + '">' + groupHtml(g, preview) + '</div>';
        }).join('') +
        '<div class="dfb-wiz-nav">' +
          '<button type="button" class="btn btn-ghost" data-wiz-back>← Back</button>' +
          '<span class="dfb-wiz-spacer"></span>' +
          '<button type="button" class="btn btn-primary" data-wiz-next>Next →</button>' +
        '</div></div>';
    } else {
      html = groups.map(function (g) { return groupHtml(g, preview); }).join('');
    }

    $container.html(html);
    $container.data('dfbForm', form);
    $container.data('dfbStep', 0);

    if (!preview && window.CMS && CMS.initSelect2) CMS.initSelect2($container[0]);
    bindGridButtons($container, form, preview);
    bindWizard($container, form, groups);
    loadLookups($container);
  }

  /* ---------------- grid interactions ---------------- */
  function bindGridButtons($container, form, preview) {
    if (preview) return;
    var byKey = {};
    (form.fields || []).forEach(function (f) { byKey[f.fieldKey] = f; });
    $container.off('click.dfbgrid').on('click.dfbgrid', '.dfb-grid-add', function () {
      var $wrap = $(this).closest('.dfb-grid-wrap');
      var f = byKey[$wrap.data('grid-field')];
      if (f) $wrap.find('tbody').append(gridRowHtml(f, false));
    });
    $container.on('click.dfbgrid', '.dfb-grid-del', function () {
      var $tr = $(this).closest('tr');
      var $body = $tr.closest('tbody');
      if ($body.find('tr').length > 1) $tr.remove();
      else $tr.find('.dfb-grid-cell').val('');
    });
  }

  /* ---------------- lookup loading ---------------- */
  function loadLookups($container) {
    if (typeof window.cmsAjax !== 'function') return;
    $container.find('select[data-lookup-form]').each(function () {
      var $sel = $(this);
      var formId = $sel.data('lookup-form');
      var fieldKey = $sel.data('lookup-field');
      if (!formId || !fieldKey) return;
      window.cmsAjax({
        url: '/api/dynamic-forms/lookup-options?formId=' + encodeURIComponent(formId) +
             '&fieldKey=' + encodeURIComponent(fieldKey),
        method: 'GET', auth: true,
        fallbackMsg: 'Could not load lookup options.',
        success: function (options) {
          var def = $sel.data('default');
          var html = '<option value="">' + ($sel.find('option:first').text() || 'Select…') + '</option>';
          (options || []).forEach(function (o) {
            html += '<option value="' + esc(o.value) + '"' +
              (def != null && String(def) === String(o.value) ? ' selected' : '') + '>' + esc(o.label) + '</option>';
          });
          $sel.html(html);
          if (window.CMS && CMS.initSelect2) CMS.initSelect2($sel.closest('div')[0] || $container[0]);
        },
        error: function () { return true; } // keep the empty select; no toast on a lookup
      });
    });
  }

  /* ---------------- wizard ---------------- */
  function wizardGoTo($container, groups, i) {
    $container.data('dfbStep', i);
    $container.find('.dfb-step').each(function (s) { $(this).toggleClass('active', s === i); });
    var g = groups[i] || {};
    $container.find('.dfb-wiz-label').text('Step ' + (i + 1) + ' of ' + groups.length + (g.title ? ' — ' + g.title : ''));
    $container.find('.dfb-wiz-bar i').css('width', Math.round(((i + 1) / groups.length) * 100) + '%');
    $container.find('[data-wiz-back]').prop('disabled', i === 0);
    $container.find('[data-wiz-next]').toggle(i < groups.length - 1);
  }

  function bindWizard($container, form, groups) {
    var $wiz = $container.find('.dfb-wizard');
    if (!$wiz.length) return;
    wizardGoTo($container, groups, 0);
    $wiz.off('click.dfbwiz').on('click.dfbwiz', '[data-wiz-back]', function () {
      wizardGoTo($container, groups, Math.max(0, ($container.data('dfbStep') || 0) - 1));
    });
    $wiz.on('click.dfbwiz', '[data-wiz-next]', function () {
      var i = $container.data('dfbStep') || 0;
      var errors = validateFields($container, groups[i].fields);
      if (errors.length) {
        if (window.CMS && CMS.toast) CMS.toast(errors.map(function (e) { return e.message; }).slice(0, 3).join(' '), 'error');
        showField($container, errors[0].fieldKey);
        return;
      }
      wizardGoTo($container, groups, Math.min(groups.length - 1, i + 1));
    });
  }

  /* ---------------- collect + validate ---------------- */
  function collect($root) {
    var data = {};
    // Grid/table fields first (their cells carry no name attribute).
    $root.find('.dfb-grid-wrap').each(function () {
      var key = $(this).data('grid-field');
      var rows = [];
      $(this).find('tbody tr').each(function () {
        var row = {};
        $(this).find('.dfb-grid-cell').each(function () { row[$(this).data('col')] = $(this).val(); });
        rows.push(row);
      });
      data[key] = rows;
    });
    $root.find('[name]').each(function () {
      var $el = $(this);
      var name = $el.attr('name');
      if ($el.is(':checkbox')) {
        if ($el.closest('.dfb-choices').length) {
          data[name] = data[name] || [];
          if ($el.is(':checked')) data[name].push($el.val());
        } else {
          data[name] = $el.is(':checked');
        }
      } else if ($el.is(':radio')) {
        if ($el.is(':checked')) data[name] = $el.val();
      } else if ($el.is('select[multiple]')) {
        data[name] = $el.val() || [];
      } else if ($el.is(':file')) {
        data[name] = $el.val() ? $el.val().split('\\').pop() : null;
      } else {
        data[name] = $el.val();
      }
    });
    return data;
  }

  function isEmptyValue(v) {
    return v == null || v === '' || v === false || (Array.isArray(v) && !v.length);
  }

  function gridHasData(rows) {
    return (rows || []).some(function (r) {
      return Object.keys(r).some(function (k) { return r[k] != null && String(r[k]).trim() !== ''; });
    });
  }

  /* Validate a set of field definitions against the values under $root.
     Returns [{ fieldKey, label, message }]. Used by the wizard (per step)
     and by the render page (whole form). */
  function validateFields($root, fields) {
    var data = collect($root);
    var errors = [];
    (fields || []).forEach(function (f) {
      if (STATIC_TYPES[f.fieldType] || f.fieldType === 'hidden') return;
      var v = data[f.fieldKey];
      if (f.isRequired) {
        var missing = f.fieldType === 'grid' ? !gridHasData(v) : isEmptyValue(v);
        if (missing) {
          errors.push({ fieldKey: f.fieldKey, label: f.label, message: f.label + ' is required.' });
          return;
        }
      }
      if (f.regexPattern && typeof v === 'string' && v !== '') {
        var ok = true;
        try { ok = new RegExp(f.regexPattern).test(v); } catch (e) { ok = true; }
        if (!ok) {
          errors.push({ fieldKey: f.fieldKey, label: f.label,
            message: f.validationMessage || (f.label + ' has an invalid format.') });
        }
      }
    });
    return errors;
  }

  function validate($root, form) {
    return validateFields($root, (form && form.fields) || []);
  }

  /* Bring a field into view: activates its wizard step (if any) and focuses it. */
  function showField($root, fieldKey) {
    var $el = $root.find('[name="' + fieldKey + '"], [data-grid-field="' + fieldKey + '"]').first();
    if (!$el.length) return;
    var $step = $el.closest('.dfb-step');
    if ($step.length) {
      // Recompute groups from the stored definition to jump correctly.
      var form = $root.data('dfbForm');
      if (form) {
        var fields = (form.fields || []).slice().sort(function (a, b) { return (a.sortOrder || 0) - (b.sortOrder || 0); });
        wizardGoTo($root, groupFields(fields), Number($step.data('step')) || 0);
      }
    }
    var $focus = $el.is('[data-grid-field]') ? $el.find('.dfb-grid-cell').first() : $el;
    if ($focus.length) $focus.focus();
  }

  return {
    render: render, collect: collect, fieldHtml: fieldHtml,
    validate: validate, validateFields: validateFields, showField: showField,
    OPTION_TYPES: OPTION_TYPES
  };
})();

