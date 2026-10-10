/* ==========================================================================
   CMS · Integrated Mental Health Programme — js/validation.js
   jQuery form validation — $.fn.cmsValidate
   --------------------------------------------------------------------------
   MARKUP CONTRACT — every required input must be wrapped like this:
     <div class="field">
       <label>Full Name <span class="req">*</span></label>
       <input class="input" name="fullName" required>
       <span class="field-error"></span>
     </div>
   The plugin auto-applies to any form with the [data-validate] attribute:
     <form data-validate>
   Supported extras on inputs:
     type="email"          → email format check
     data-validate="phone" → phone number check
     data-match="#pass"    → must equal the value of the given selector
     data-minlength="8"    → minimum character length
   Invalid fields get .invalid on their .field wrapper and a message in
   .field-error (styled in css/style.css). Errors clear live on input.
   ========================================================================== */

$.fn.cmsValidate = function(opts){
  var settings = $.extend({ onValid:null, scroll:true }, opts);

  return this.each(function(){
    var $f = $(this);
    if ($f.data('cmsv')) {
      // Already bound (e.g. via CMS.initValidation): just refresh the
      // settings so a later onValid handler is not silently dropped.
      $f.data('cmsv-settings', settings);
      return;
    }
    $f.data('cmsv', true);
    $f.data('cmsv-settings', settings);

    $f.on('submit', function(e){
      e.preventDefault();

      var s = $f.data('cmsv-settings') || settings;
      var ok = true, first = null;
      $f.find('.field').removeClass('invalid');

      $f.find('[required]').each(function(){
        var $i = $(this),
            v = $.trim($i.val() || ''),
            bad = false,
            msg = 'This field is required';

        if (!v){
          bad = true;
        } else if ($i.attr('type') === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)){
          bad = true; msg = 'Enter a valid email address';
        } else if ($i.data('validate') === 'phone' && !/^[0-9+\-\s]{7,15}$/.test(v)){
          bad = true; msg = 'Enter a valid phone number';
        } else if ($i.data('match') && v !== $($i.data('match')).val()){
          bad = true; msg = 'Values do not match';
        } else if ($i.data('minlength') && v.length < +$i.data('minlength')){
          bad = true; msg = 'Minimum ' + $i.data('minlength') + ' characters';
        }

        if (bad){
          ok = false;
          var $fld = $i.closest('.field');
          $fld.addClass('invalid');
          $fld.find('.field-error').text(msg);
          if (!first) first = $i;
        }
      });

      if (!ok){
        if (s.scroll && first && first.length){
          $('html,body').animate({ scrollTop: first.closest('.field').offset().top - 120 }, 300);
        }
        CMS.toast('Please fix the highlighted fields.', 'error');
        return;
      }

      if (s.onValid) s.onValid($f);
    });

    // Live clear: remove the error state as soon as the user types
    $f.on('input change', '[required]', function(){
      $(this).closest('.field').removeClass('invalid');
    });
  });
};

/* Bound automatically by CMS.mountLayout(); pages can also call it directly. */
CMS.initValidation = function(scope){
  $(scope).find('form[data-validate]').cmsValidate();
};
