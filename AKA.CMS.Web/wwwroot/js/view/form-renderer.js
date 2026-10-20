/* Dynamic Form Renderer — renders a saved form definition with the app
   theme (.field / .input / .select2 / .check-row). Used by the Render page
   and the builder's live preview.
   Usage: CMSFormRenderer.render($container, formDetail, { preview: true }) */
window.CMSFormRenderer = (function () {
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }); }

  var OPTION_TYPES = { select: 1, multiselect: 1, radio: 1, checkboxGroup: 1 };

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
        inner = labelHtml(f) + '<div class="dfb-choices">' + (f.options || []).map(function (o) {
          var chk = f.defaultValue != null && String(f.defaultValue) === String(o.value) ? ' checked' : '';
          return '<label class="check-row"><input type="radio" name="' + key + '" value="' + esc(o.value) + '"' + chk + dis + '>' +
            '<span class="check-label">' + esc(o.label) + '</span></label>';
        }).join('') + '</div>' + helpHtml(f);
        break;
      case 'checkboxGroup':
        inner = labelHtml(f) + '<div class="dfb-choices">' + (f.options || []).map(function (o) {
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

  function render($container, form, opts) {
    opts = opts || {};
    var fields = (form.fields || []).slice().sort(function (a, b) { return (a.sortOrder || 0) - (b.sortOrder || 0); });
    $container.html('<div class="dfb-grid">' + fields.map(function (f) { return fieldHtml(f, !!opts.preview); }).join('') + '</div>');
    if (!opts.preview && window.CMS && CMS.initSelect2) CMS.initSelect2($container[0]);
  }

  /* Collect current values from a rendered form: { fieldKey: value | [values] } */
  function collect($root) {
    var data = {};
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

  return { render: render, collect: collect, fieldHtml: fieldHtml, OPTION_TYPES: OPTION_TYPES };
})();
