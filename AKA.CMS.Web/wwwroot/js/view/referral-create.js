/* Create Referral — 3-step wizard matching the CMO design.
   Providers are loaded from /api/facilities; submit posts to /api/referrals. */
$(function () {
  if (window.cmsAuth && !window.cmsAuth.isLoggedIn()) { window.location.href = '/Account/Login'; return; }
  CMS.bindLayout();
  CMS.initSelect2($('#refForm'));
  $('[data-go]').on('click', function () { location.href = $(this).data('go'); });

  var step = 1;
  var selectedProvider = '';

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function val(id) { return $.trim($('#' + id).val() || ''); }

  /* ---------- cases dropdown ---------- */
  cmsAjax({ url: '/api/cases', method: 'GET',
    fallbackMsg: 'Could not load cases.',
    success: function (res) {
      var html = '<option value="" selected disabled>Select case</option>';
      (res || []).forEach(function (c) {
        html += '<option value="' + c.caseId + '">' + esc(c.caseNumber || ('Case #' + c.caseId)) + '</option>';
      });
      $('#rCase').html(html);
    }
  });

  /* ---------- providers ---------- */
  var providers = [];
  function renderProviders(filter) {
    var list = providers.filter(function (p) {
      return !filter || p.name.toLowerCase().indexOf(filter.toLowerCase()) >= 0;
    });
    $('#provList').html(list.map(function (p, i) {
      return '<label class="quick card" style="box-shadow:none;cursor:pointer"><div class="left">' +
        '<input type="radio" name="provider" value="' + esc(p.name) + '"' + (i === 0 && !selectedProvider ? ' checked' : '') + '>' +
        '<div><b>' + esc(p.name) + '</b><div style="font-size:12px;color:#8995a7">' + esc(p.sub) + '</div></div>' +
        '</div></label>';
    }).join('') || '<div class="empty">No providers found.</div>');
    $('#provList input[name=provider]').on('change', function () { selectedProvider = $(this).val(); });
    if (!selectedProvider && list.length) selectedProvider = list[0].name;
  }
  cmsAjax({ url: '/api/facilities', method: 'GET',
    fallbackMsg: 'Could not load providers.',
    success: function (res) {
      providers = (res || []).map(function (f) {
        return { name: f.facilityName, sub: (f.facilityType || 'Facility') + (f.region ? ' | ' + f.region : '') };
      });
      if (!providers.length) {
        providers = [
          { name: 'Psychologist', sub: 'Mental Health Services' },
          { name: 'Psychiatrist', sub: 'Mental Health Services' }
        ];
      }
      renderProviders('');
    },
    error: function () {
      providers = [{ name: 'Psychologist', sub: 'Mental Health Services' }];
      renderProviders('');
    }
  });
  $('#provSearch').on('input', function () { renderProviders($(this).val()); });

  /* ---------- steps ---------- */
  function showStep(n) {
    step = n;
    $('.ref-step').prop('hidden', true);
    $('#rf' + n).prop('hidden', false);
    $('#refSteps .step').each(function () {
      var s = parseInt($(this).data('step'), 10);
      $(this).toggleClass('done', s < n).toggleClass('current', s === n);
      $(this).find('.circle').text(s < n ? '✓' : s);
    });
    if (n === 3) buildReview();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
  function validateStep1() {
    var ok = true;
    $('#rf1 .field').removeClass('invalid');
    $('#rf1 [required]').each(function () {
      if (!$.trim($(this).val() || '')) {
        $(this).closest('.field').addClass('invalid');
        $(this).closest('.field').find('.field-error').text('This field is required.');
        ok = false;
      }
    });
    if (!ok) CMS.toast('Please fix the highlighted fields.', 'error');
    return ok;
  }
  $('#rfNext1').on('click', function () { if (validateStep1()) showStep(2); });
  $('#rfNext2').on('click', function () {
    var sel = $('#provList input[name=provider]:checked').val();
    if (sel) selectedProvider = sel;
    if (!selectedProvider) { CMS.toast('Please select a provider.', 'error'); return; }
    showStep(3);
  });
  $('#rfBack2').on('click', function () { showStep(1); });
  $('#rfBack3').on('click', function () { showStep(2); });

  function kv(k, v) { return '<div class="k">' + esc(k) + '</div><div class="v">' + esc(v || '—') + '</div>'; }
  function buildReview() {
    $('#refReview').html(
      kv('Case', $('#rCase option:selected').text()) +
      kv('Service / Specialty', val('rService')) +
      kv('Reason', val('rReason')) +
      kv('Priority', val('rPriority')) +
      kv('Provider', selectedProvider) +
      kv('Clinical Summary', val('rSummary'))
    );
  }

  /* ---------- submit ---------- */
  $('#rfSubmit').on('click', function () {
    var payload = {
      caseId: parseInt(val('rCase'), 10),
      referredTo: selectedProvider,
      slaDueAt: null,
      notes: ['Service: ' + val('rService'), 'Reason: ' + val('rReason'), 'Priority: ' + val('rPriority'), val('rSummary')]
        .filter(Boolean).join(' | ')
    };
    CMS.loader(true);
    cmsAjax({
      url: '/api/referrals', method: 'POST', json: true, data: payload,
      fallbackMsg: 'Could not submit the referral.',
      success: function (r) {
        CMS.loader(false);
        CMS.toast('Referral ' + (r.referralNumber || '') + ' submitted.', 'success');
        location.href = '/Referrals/Details/' + r.referralId;
      },
      error: function () { CMS.loader(false); }
    });
  });

  showStep(1);
});
