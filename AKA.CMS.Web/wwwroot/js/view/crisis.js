/* Crisis Protocol — per-case crisis response (Figma flow):
   protocol panel → 4-step response wizard → escalation → timeline.
   Data comes DIRECTLY from the Web API via cmsAjax. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2(document);

  var caseId = window.__crisisCaseId;
  var caseInfo = null;
  var crisisTypes = [];
  var activeEvent = null;

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

  function fmtDT(d) {
    if (!d) return '—';
    return new Date(d).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  /* ---------- load ---------- */
  function load() {
    cmsAjax({
      url: '/api/cases/' + caseId, method: 'GET', fallbackMsg: 'Could not load the case.',
      success: function (c) {
        caseInfo = c;
        $('#crisisCaseSub').text((c.caseNumber || ('#' + c.caseId)) + ' · ' + (c.memberName || 'Unknown patient'));
        $('#followUpLink').attr('href', '/Appointments');
      },
      error: function () { $('#crisisCaseSub').text('Case not found.'); }
    });
    cmsAjax({
      url: '/api/crisis-events/types', method: 'GET', fallbackMsg: '',
      success: function (res) { crisisTypes = res || []; }
    });
    loadEvents();
  }

  function loadEvents() {
    cmsAjax({
      url: '/api/crisis-events/case/' + caseId, method: 'GET',
      fallbackMsg: 'Could not load crisis events.',
      success: function (res) {
        var events = res || [];
        activeEvent = events.find(function (e) { return e.status === 'Active' || e.status === 'Escalated'; }) || null;
        renderIndicators(events);
        renderEvents(events);
        if (window.CMS && typeof CMS.applyPermissions === 'function') CMS.applyPermissions(document);
      }
    });
  }

  function renderIndicators(events) {
    var html = '';
    if (activeEvent) {
      html += '<li><span class="k">Active crisis:</span> ' + esc(activeEvent.crisisTypeName || activeEvent.crisisTypeCode) +
              ' · Severity ' + esc(activeEvent.severity) + '</li>';
    }
    var recent = events.slice(0, 3);
    if (recent.length) {
      html += '<li><span class="k">Recent events:</span> ' + recent.map(function (e) {
        return esc(e.crisisTypeName || e.crisisTypeCode) + ' (' + fmtDT(e.createdAt) + ')';
      }).join('; ') + '</li>';
    }
    html += '<li><span class="k">Risk level:</span> ' + (activeEvent ? esc(activeEvent.severity) : 'No active crisis — monitor') + '</li>';
    $('#indicatorList').html(html);
  }

  function renderEvents(events) {
    if (!events.length) {
      $('#crisisEvents').html('<p class="hint">No crisis events recorded for this case.</p>');
      return;
    }
    var html = '';
    events.forEach(function (e) {
      var isActive = e.status === 'Active' || e.status === 'Escalated';
      html += '<div class="ev-card" data-id="' + e.crisisEventId + '" data-rv="' + esc(e.rowVersion || '') + '">' +
        '<div class="ev-head"><div><strong>' + esc(e.crisisTypeName || e.crisisTypeCode) + '</strong> ' +
        '<span class="pill ' + (isActive ? 'pill-high' : 'pill-completed') + '">' + esc(e.status) + '</span></div>' +
        (isActive ? '<div data-permission="Crisis:Write">' +
          (e.status === 'Active' ? '<button class="btn btn-ghost btn-sm" data-ev-escalate>Escalate</button> ' : '') +
          '<button class="btn btn-ghost btn-sm" data-ev-stabilize>Mark Stabilized</button></div>' : '') +
        '</div>' +
        '<div class="t-meta" style="color:#666;font-size:13px;margin-top:4px">Severity: ' + esc(e.severity) +
        ' · Source: ' + esc(e.triggerSource) + ' · ' + fmtDT(e.createdAt) +
        (e.createdByUsername ? ' · by ' + esc(e.createdByUsername) : '') + '</div>' +
        (e.notes ? '<div style="margin-top:6px;font-size:14px">' + esc(e.notes) + '</div>' : '') +
        '</div>';
    });
    $('#crisisEvents').html(html);
  }

  /* ---------- event actions ---------- */
  function updateEventStatus(card, newStatus) {
    cmsAjax({
      url: '/api/crisis-events/' + card.data('id') + '/status', method: 'PATCH',
      data: JSON.stringify({ newStatus: newStatus, rowVersion: card.data('rv') }),
      fallbackMsg: 'Could not update the crisis event.',
      success: function () { CMS.toast('Crisis event updated.', 'success'); loadEvents(); }
    });
  }
  $('#crisisEvents').on('click', '[data-ev-escalate]', function () { updateEventStatus($(this).closest('.ev-card'), 'ESCALATED'); });
  $('#crisisEvents').on('click', '[data-ev-stabilize]', function () { updateEventStatus($(this).closest('.ev-card'), 'STABILIZED'); });

  /* ---------- wizard ---------- */
  function goStep(n) {
    $('#responseModal [data-pane]').hide();
    $('#responseModal [data-pane="' + n + '"]').show();
    $('#crisisSteps .step').each(function () {
      var s = +$(this).data('step');
      $(this).toggleClass('done', s < n).toggleClass('current', s === n);
      $(this).find('.circle').text(s < n ? '✓' : s);
    });
  }
  function openModal() { goStep(1); $('#responseModal').addClass('open').css('display', 'flex'); }
  function closeModal() { $('#responseModal').removeClass('open').css('display', 'none'); }

  $('#startResponseBtn').on('click', openModal);
  $('#viewChecklistBtn').on('click', function () {
    location.href = '/Cases/Timeline?id=' + caseId;
  });
  $('#responseModal').on('click', '[data-close]', closeModal);
  $('#responseModal').on('click', function (e) { if (e.target === this) closeModal(); });
  $('#toAssess').on('click', function () { goStep(2); });
  $('#backToContact').on('click', function () { goStep(1); });
  $('#toEscalate').on('click', function () { goStep(3); });
  $('#backToAssess').on('click', function () { goStep(2); });

  $('#escalateBtn').on('click', function () {
    var reason = $.trim($('#cReason').val());
    if (!reason) {
      $('#cReason').closest('.field').addClass('invalid').find('.field-error').text('Reason for escalation is required.');
      return;
    }
    var $btn = $(this).prop('disabled', true);
    var notes = 'Contact: ' + $('input[name=cM]:checked').val() + ' — ' + $('#cOutcome').val() +
      ($('#cNotes').val() ? '. ' + $.trim($('#cNotes').val()) : '') +
      ' | Risk change: ' + $('input[name=cR]:checked').val() + ' (severity ' + $('#cSeverity').val() + ')' +
      ($('#cAssessNotes').val() ? '. ' + $.trim($('#cAssessNotes').val()) : '');

    function escalateEvent(eventId, rowVersion) {
      cmsAjax({
        url: '/api/crisis-events/' + eventId + '/status', method: 'PATCH',
        data: JSON.stringify({ newStatus: 'ESCALATED', rowVersion: rowVersion }),
        fallbackMsg: 'Could not escalate the case.',
        success: function () { onEscalated(); },
        complete: function () { $btn.prop('disabled', false); }
      });
    }

    function onEscalated() {
      $('#escalatedMsg').text('The case ' + (caseInfo ? (caseInfo.caseNumber || '') : '') +
        ' has been assigned to the crisis and emergency team. Escalation: ' + $('input[name=cE]:checked').val() + '.');
      goStep(4);
      loadEvents();
    }

    var typeCode = (crisisTypes[0] && crisisTypes[0].crisisTypeCode) || 'OTHER';
    if (activeEvent) {
      escalateEvent(activeEvent.crisisEventId, activeEvent.rowVersion);
    } else {
      // No active event: trigger one, then escalate it.
      cmsAjax({
        url: '/api/crisis-events', method: 'POST',
        data: JSON.stringify({
          caseId: caseId, crisisTypeCode: typeCode,
          severity: $('#cSeverity').val(), triggerSource: 'MANUAL',
          notes: notes + ' | Escalation: ' + $('input[name=cE]:checked').val() + '. Reason: ' + reason
        }),
        fallbackMsg: 'Could not record the crisis response.',
        success: function (res) { escalateEvent(res.event.crisisEventId, res.event.rowVersion); },
        error: function () { $btn.prop('disabled', false); }
      });
    }
  });

  load();
});
