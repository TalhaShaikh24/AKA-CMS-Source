/* Screening Tools management — dynamic CRUD via /api/screening-tools */
(function () {
  'use strict';

  var allTools = [];
  var editingCode = null;

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

  function load() {
    cmsAjax({
      url: '/api/screening-tools', method: 'GET',
      fallbackMsg: 'Could not load screening tools.',
      success: function (res) { allTools = res || []; render(); }
    });
  }

  function render() {
    var html = '';
    allTools.forEach(function (t) {
      html += '<div class="geo-card">' +
        '<div class="geo-card-main"><div class="geo-card-name">' + esc(t.toolName) + ' <span class="hint">(' + esc(t.toolCode) + ')</span></div>' +
        '<div class="geo-card-sub">' + esc(t.description || '—') + ' · ' + t.questionCount + ' questions</div></div>' +
        '<div class="geo-card-side">' +
        '<span class="badge ' + (t.isActive ? 'st-active' : 'st-ltfu') + '">' + (t.isActive ? 'Active' : 'Inactive') + '</span>' +
        '<button class="btn btn-ghost btn-sm" data-edit-tool="' + esc(t.toolCode) + '" type="button">Edit</button>' +
        '</div></div>';
    });
    $('#toolRows').html(html || '<div class="hint geo-empty">No screening tools yet.</div>');
    if (window.CMS && typeof CMS.applyPermissions === 'function') CMS.applyPermissions(document);
  }

  /* ---------- question editor ---------- */
  function questionRow(q) {
    q = q || { text: '', options: [{ t: '', v: 0 }] };
    var opts = (q.options || []).map(function (o) {
      return '<div class="q-opt" style="display:flex;gap:8px;margin-bottom:6px">' +
        '<input class="input" data-qopt-t value="' + esc(o.t) + '" placeholder="Option text" style="flex:1">' +
        '<input class="input" data-qopt-v value="' + esc(o.v) + '" placeholder="Value" type="number" style="width:90px" data-mask="number">' +
        '<button type="button" class="btn btn-ghost btn-sm" data-rm-opt>×</button></div>';
    }).join('');
    return '<div class="q-row card" style="padding:12px;margin-bottom:10px;box-shadow:none">' +
      '<div class="field" style="margin-bottom:8px"><label>Question</label>' +
      '<input class="input" data-q-text value="' + esc(q.text) + '" placeholder="Question text"></div>' +
      '<label class="hint">Options (text + score value)</label><div data-q-opts>' + opts + '</div>' +
      '<div style="display:flex;gap:8px;margin-top:6px">' +
      '<button type="button" class="btn btn-ghost btn-sm" data-add-opt>+ Option</button>' +
      '<button type="button" class="btn btn-ghost btn-sm" data-rm-q style="margin-left:auto">Remove question</button>' +
      '</div></div>';
  }

  $(document).on('click', '#addQuestionBtn', function () {
    $('#stQuestions').append(questionRow());
    if (window.CMSValidator) CMSValidator.init($('#stQuestions')[0]);
  });
  $(document).on('click', '[data-add-opt]', function () {
    $(this).closest('.q-row').find('[data-q-opts]').append(
      '<div class="q-opt" style="display:flex;gap:8px;margin-bottom:6px">' +
      '<input class="input" data-qopt-t placeholder="Option text" style="flex:1">' +
      '<input class="input" data-qopt-v placeholder="Value" type="number" style="width:90px" data-mask="number">' +
      '<button type="button" class="btn btn-ghost btn-sm" data-rm-opt>×</button></div>');
  });
  $(document).on('click', '[data-rm-opt]', function () { $(this).closest('.q-opt').remove(); });
  $(document).on('click', '[data-rm-q]', function () { $(this).closest('.q-row').remove(); });

  function collectQuestions() {
    var list = [];
    $('#stQuestions .q-row').each(function () {
      var text = $.trim($(this).find('[data-q-text]').val());
      if (!text) return;
      var opts = [];
      $(this).find('.q-opt').each(function () {
        var t = $.trim($(this).find('[data-qopt-t]').val());
        var v = $(this).find('[data-qopt-v]').val();
        if (t !== '') opts.push({ t: t, v: v === '' ? 0 : parseInt(v, 10) || 0 });
      });
      if (opts.length) list.push({ text: text, options: opts });
    });
    return list;
  }

  /* ---------- add / edit ---------- */
  $('#addToolBtn').on('click', function () {
    editingCode = null;
    $('#toolModalTitle').text('New Screening Tool');
    $('#toolFormSubmit').text('Create Tool');
    $('#toolForm')[0].reset();
    $('#stCode').prop('disabled', false);
    $('#stMaxScore').val('3');
    $('#stSort').val('0');
    $('#stActive').prop('checked', true);
    $('#stQuestions').html('');
    $('#toolModal').addClass('open');
  });

  $(document).on('click', '[data-edit-tool]', function () {
    var code = $(this).data('edit-tool');
    cmsAjax({
      url: '/api/screening-tools/' + encodeURIComponent(code), method: 'GET',
      fallbackMsg: 'Could not load tool.',
      success: function (t) {
        editingCode = t.toolCode;
        $('#toolModalTitle').text('Edit — ' + t.toolName);
        $('#toolFormSubmit').text('Save Changes');
        $('#stCode').val(t.toolCode).prop('disabled', true);
        $('#stName').val(t.toolName);
        $('#stDesc').val(t.description || '');
        $('#stSort').val(t.sortOrder || 0);
        $('#stActive').prop('checked', !!t.isActive);
        var qs = [];
        try { qs = JSON.parse(t.questionsJson || t.QuestionsJson || '[]'); } catch (e) { qs = []; }
        $('#stQuestions').html(qs.map(function (q) {
          var text = q.text || q.QuestionText || q.questionText || '';
          var opts = q.options || q.Options || [];
          return questionRow({ text: text, options: opts.map(function (o) { return { t: o.t, v: o.v }; }) });
        }).join(''));
        // MaxItemScore: derive from first question options if available
        $('#toolModal').addClass('open');
      }
    });
  });

  $('#toolForm').cmsValidate({
    onValid: function () {
      var questions = collectQuestions();
      var payload = {
        toolName: $.trim($('#stName').val()),
        description: $.trim($('#stDesc').val()) || null,
        isActive: $('#stActive').is(':checked'),
        sortOrder: parseInt($('#stSort').val() || '0', 10),
        questions: questions.length ? questions : null
      };
      if (editingCode) {
        cmsAjax({
          url: '/api/screening-tools/' + encodeURIComponent(editingCode), method: 'PUT', json: true,
          data: payload,
          fallbackMsg: 'Could not update tool.',
          success: function () {
            $('#toolModal').removeClass('open');
            CMS.toast('Screening tool updated.', 'success');
            load();
          }
        });
      } else {
        payload.toolCode = $.trim($('#stCode').val()).toUpperCase();
        payload.itemCount = questions.length || 1;
        payload.maxItemScore = parseInt($('#stMaxScore').val() || '3', 10);
        cmsAjax({
          url: '/api/screening-tools', method: 'POST', json: true,
          data: payload,
          fallbackMsg: 'Could not create tool.',
          success: function () {
            $('#toolModal').removeClass('open');
            CMS.toast('Screening tool created.', 'success');
            load();
          }
        });
      }
    }
  });

  load();
})();
