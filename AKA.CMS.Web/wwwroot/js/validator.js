/* ==========================================================================
   CMS Validator — standalone input validation library
   --------------------------------------------------------------------------
   USAGE:
     1. Wrap each input in:  <div class="field">
                                <input class="input" data-validate="email" data-required>
                                <span class="field-error"></span>
                              </div>
     2. Call:  CMSValidator.validateForm(formElement)  → true/false
        or:    CMSValidator.validateField(inputElement) → true/false
     3. Masks: add data-mask="phone|cnic|number|decimal" for live formatting.

   RULES (data-validate, pipe-separated for multiple, e.g. "required|email"):
     required   → value must not be empty
     email      → valid email address
     phone      → valid phone (digits, +, -, spaces; 7–15 chars)
     number     → numeric value (integer or decimal)
     integer    → whole number (no decimals)
     decimal    → decimal number
     url        → valid http/https URL
     date       → valid date
     cnic       → Pakistani CNIC (XXXXX-XXXXXXX-X)
     alpha      → letters only
     alphanum   → letters + numbers only

   RANGE / LENGTH (data attributes):
     data-min="5"          → numeric value >= 5
     data-max="100"        → numeric value <= 100
     data-minlength="3"    → text length >= 3
     data-maxlength="50"   → text length <= 50
     data-pattern="^A.+"   → custom regex must match
     data-match="#passId"  → value must equal the matched field

   CUSTOM MESSAGES:
     data-msg="Custom message for any failure"
     data-msg-required="Please fill this in"
     data-msg-email="Enter a valid email address"
     ... (data-msg-<rule> for any rule above)

   MASKS (data-mask, applied live while typing):
     phone    → digits, +, -, spaces only
     cnic     → XXXXX-XXXXXXX-X auto-dash
     number   → digits only
     decimal  → digits + single dot
   ========================================================================== */
(function (global) {
  'use strict';

  var PATTERNS = {
    email: /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/,
    phone: /^[0-9+\-\s()]{7,18}$/,
    number: /^-?\d+(\.\d+)?$/,
    integer: /^-?\d+$/,
    decimal: /^-?\d+(\.\d+)?$/,
    url: /^(https?:\/\/)[^\s/$.?#].[^\s]*$/i,
    cnic: /^\d{5}-\d{7}-\d{1}$/,
    alpha: /^[A-Za-z\s]+$/,
    alphanum: /^[A-Za-z0-9\s]+$/
  };

  var DEFAULT_MESSAGES = {
    required: 'This field is required.',
    email: 'Please enter a valid email address.',
    phone: 'Please enter a valid phone number.',
    number: 'Please enter a valid number.',
    integer: 'Please enter a whole number.',
    decimal: 'Please enter a valid decimal number.',
    url: 'Please enter a valid URL (starting with http:// or https://).',
    date: 'Please enter a valid date.',
    cnic: 'Please enter a valid CNIC (e.g. 42101-1234567-1).',
    alpha: 'Letters only, please.',
    alphanum: 'Letters and numbers only, please.',
    min: 'Value must be at least {0}.',
    max: 'Value must be no more than {0}.',
    minlength: 'Please enter at least {0} characters.',
    maxlength: 'Please enter no more than {0} characters.',
    pattern: 'The value format is not valid.',
    match: 'Values do not match.'
  };

  function fmt(msg, arg) { return String(msg).replace('{0}', arg); }

  function getMessage(input, rule, arg) {
    var custom = input.getAttribute('data-msg-' + rule) || input.getAttribute('data-msg');
    if (custom) return arg !== undefined ? fmt(custom, arg) : custom;
    var def = DEFAULT_MESSAGES[rule] || 'Invalid value.';
    return arg !== undefined ? fmt(def, arg) : def;
  }

  function showError(input, message) {
    var field = input.closest('.field');
    if (field) field.classList.add('invalid');
    var err = field ? field.querySelector('.field-error') : null;
    if (err) { err.textContent = message; err.style.display = 'block'; }
    input.setAttribute('aria-invalid', 'true');
  }

  function clearError(input) {
    var field = input.closest('.field');
    if (field) field.classList.remove('invalid');
    var err = field ? field.querySelector('.field-error') : null;
    if (err) { err.textContent = ''; err.style.display = ''; }
    input.removeAttribute('aria-invalid');
  }

  function isEmpty(value) { return value === null || value === undefined || String(value).trim() === ''; }

  function validateField(input) {
    if (input.disabled || input.type === 'hidden') return true;
    clearError(input);

    var raw = input.value;
    var value = typeof raw === 'string' ? raw.trim() : raw;
    var rules = (input.getAttribute('data-validate') || '').split('|').map(function (r) { return r.trim(); }).filter(Boolean);
    var isRequired = rules.indexOf('required') >= 0 || input.hasAttribute('required') || input.getAttribute('data-required') !== null;

    // Empty + not required → valid (skip all other checks)
    if (isEmpty(value)) {
      if (isRequired) { showError(input, getMessage(input, 'required')); return false; }
      return true;
    }

    // Rule checks
    for (var i = 0; i < rules.length; i++) {
      var rule = rules[i];
      if (rule === 'required') continue;
      if (rule === 'date') {
        var d = new Date(value);
        if (isNaN(d.getTime())) { showError(input, getMessage(input, 'date')); return false; }
        continue;
      }
      var pattern = PATTERNS[rule];
      if (pattern && !pattern.test(value)) { showError(input, getMessage(input, rule)); return false; }
    }

    // Numeric range
    var min = input.getAttribute('data-min');
    var max = input.getAttribute('data-max');
    if (min !== null || max !== null) {
      var num = parseFloat(value);
      if (isNaN(num)) { showError(input, getMessage(input, 'number')); return false; }
      if (min !== null && num < parseFloat(min)) { showError(input, getMessage(input, 'min', min)); return false; }
      if (max !== null && num > parseFloat(max)) { showError(input, getMessage(input, 'max', max)); return false; }
    }

    // Length
    var minLen = input.getAttribute('data-minlength');
    var maxLen = input.getAttribute('data-maxlength');
    if (minLen !== null && value.length < parseInt(minLen, 10)) { showError(input, getMessage(input, 'minlength', minLen)); return false; }
    if (maxLen !== null && value.length > parseInt(maxLen, 10)) { showError(input, getMessage(input, 'maxlength', maxLen)); return false; }

    // Custom regex
    var customPattern = input.getAttribute('data-pattern');
    if (customPattern) {
      try {
        if (!new RegExp(customPattern).test(value)) { showError(input, getMessage(input, 'pattern')); return false; }
      } catch (e) { /* ignore bad regex */ }
    }

    // Match another field
    var matchSel = input.getAttribute('data-match');
    if (matchSel) {
      var other = document.querySelector(matchSel);
      if (other && value !== other.value) { showError(input, getMessage(input, 'match')); return false; }
    }

    return true;
  }

  function validateForm(form) {
    var inputs = form.querySelectorAll('input, select, textarea');
    var ok = true, firstBad = null;
    for (var i = 0; i < inputs.length; i++) {
      if (!validateField(inputs[i])) { ok = false; if (!firstBad) firstBad = inputs[i]; }
    }
    if (!ok && firstBad) {
      var field = firstBad.closest('.field');
      var modalBody = firstBad.closest('.modal-backdrop.open');
      if (modalBody) {
        var body = modalBody.querySelector('.modal-body');
        if (body && field) body.scrollTop = body.scrollTop + field.getBoundingClientRect().top - body.getBoundingClientRect().top - 20;
      } else if (field) {
        window.scrollTo({ top: window.scrollY + field.getBoundingClientRect().top - 120, behavior: 'smooth' });
      }
      try { firstBad.focus({ preventScroll: true }); } catch (e) { /* noop */ }
    }
    return ok;
  }

  /* ---------------- input masks (live formatting) ---------------- */
  function applyMask(input) {
    var mask = input.getAttribute('data-mask');
    if (!mask || input.dataset.maskBound) return;
    input.dataset.maskBound = '1';
    input.addEventListener('input', function () {
      var v = input.value, pos = input.selectionStart;
      if (mask === 'number') {
        input.value = v.replace(/[^0-9]/g, '');
      } else if (mask === 'decimal') {
        var cleaned = v.replace(/[^0-9.]/g, '');
        var parts = cleaned.split('.');
        input.value = parts.length > 2 ? parts[0] + '.' + parts.slice(1).join('') : cleaned;
      } else if (mask === 'phone') {
        input.value = v.replace(/[^0-9+\-\s()]/g, '');
      } else if (mask === 'cnic') {
        var d = v.replace(/\D/g, '').substring(0, 13);
        var out = d.substring(0, 5);
        if (d.length > 5) out += '-' + d.substring(5, 12);
        if (d.length > 12) out += '-' + d.substring(12, 13);
        input.value = out;
      }
      try { input.setSelectionRange(pos, pos); } catch (e) { /* noop */ }
    });
  }

  function bindMasks(scope) {
    var inputs = (scope || document).querySelectorAll('input[data-mask]');
    for (var i = 0; i < inputs.length; i++) applyMask(inputs[i]);
  }

  function bindLiveClear(scope) {
    var inputs = (scope || document).querySelectorAll('input, select, textarea');
    for (var i = 0; i < inputs.length; i++) {
      (function (input) {
        if (input.dataset.liveBound) return;
        input.dataset.liveBound = '1';
        input.addEventListener('input', function () { clearError(input); });
        input.addEventListener('change', function () { clearError(input); });
      })(inputs[i]);
    }
  }

  var api = {
    validateField: validateField,
    validateForm: validateForm,
    clearError: clearError,
    showError: showError,
    bindMasks: bindMasks,
    bindLiveClear: bindLiveClear,
    init: function (scope) { bindMasks(scope); bindLiveClear(scope); },
    messages: DEFAULT_MESSAGES
  };

  global.CMSValidator = api;
})(window);
