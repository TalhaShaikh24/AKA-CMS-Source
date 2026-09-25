/* ==========================================================================
   CMS · Integrated Mental Health Programme — js/filters.js
   $.fn.cmsFilters — dynamic filter bar builder.
   --------------------------------------------------------------------------
   Usage:
     $('#myFilters').cmsFilters({
       filters: [
         { key:'risk',   label:'Risk Level', type:'select', options:['Low','Moderate','High','Crisis'] },
         { key:'status', label:'Status',     type:'select', options:['New','Active','Follow-up Due','LTFU'] },
         { key:'date',   label:'Date Range', type:'date' },
         { key:'q',      label:'Search',     type:'search', placeholder:'Name or ID…' }
       ],
       onChange: function(values){},
       resettable: true   // shows a Reset button
     });

   - Renders into an element with .filters-bar styling (adds the class if
     missing).
   - Selects are upgraded with Select2 when available; 'date' becomes a
     cms-daterange input; 'search' a plain text input.
   - Any change emits onChange({key:value}); empty values are ''.
   - Exposes getValues(): $('#myFilters').cmsFilters('getValues') — note:
     call as .data('cmsfilters').getValues().
   ========================================================================== */

(function($){
  'use strict';

  $.fn.cmsFilters = function(opts){
    // Method-style access is not used; state is exposed via data().
    if (typeof opts === 'string') return this;

    var settings = $.extend({ filters: [], onChange: null, resettable: true }, opts || {});

    return this.each(function(){
      var $bar = $(this).addClass('filters-bar');
      if ($bar.data('cmsfilters')) return;   // already built

      var state = { $bar: $bar, inputs: {} };

      state.getValues = function(){
        var out = {};
        $.each(state.inputs, function(key, $el){ out[key] = $.trim($el.val() || ''); });
        return out;
      };

      state.emit = function(){
        if (settings.onChange) settings.onChange(state.getValues());
      };

      state.reset = function(){
        $.each(state.inputs, function(key, $el){
          if ($el.is('select')){ $el.val('').trigger('change'); }
          else { $el.val('').trigger('change'); }
        });
        state.emit();
      };

      $bar.empty();

      $.each(settings.filters, function(_, f){
        var $item = $('<div class="filter-item"></div>');
        $item.append('<label>' + f.label + '</label>');

        var $ctrl;
        if (f.type === 'select'){
          $ctrl = $('<select class="input select2" data-key="' + f.key + '"></select>');
          $ctrl.append('<option value="">All ' + f.label + '</option>');
          $.each(f.options || [], function(_, opt){
            var val = typeof opt === 'object' ? opt.value : opt;
            var txt = typeof opt === 'object' ? (opt.text || opt.value) : opt;
            $ctrl.append('<option value="' + val + '">' + txt + '</option>');
          });
          $ctrl.on('change', state.emit);
        } else if (f.type === 'date' || f.type === 'daterange'){
          $ctrl = $('<input type="text" class="input cms-daterange" data-key="' + f.key +
                    '" placeholder="' + (f.placeholder || 'Select date range') + '" readonly>');
          $ctrl.on('change', state.emit);
        } else { // 'search'
          $ctrl = $('<input type="text" class="input" data-key="' + f.key +
                    '" placeholder="' + (f.placeholder || 'Search…') + '">');
          var t;
          $ctrl.on('input', function(){ clearTimeout(t); t = setTimeout(state.emit, 350); });
        }

        state.inputs[f.key] = $ctrl;
        $item.append($ctrl);
        $bar.append($item);
      });

      if (settings.resettable){
        var $reset = $('<button type="button" class="btn btn-ghost btn-sm filters-reset">Reset</button>');
        $reset.on('click', state.reset);
        $bar.append($reset);
      }

      $bar.data('cmsfilters', state);

      // Upgrade selects & date inputs inside the bar
      if (typeof CMS !== 'undefined'){
        CMS.initSelect2($bar);
        CMS.initDateRange($bar);
      } else {
        if ($.fn.select2) $bar.find('select.select2').select2({ width:'100%' });
        if ($.fn.cmsDateRange) $bar.find('input.cms-daterange').cmsDateRange({ mode:'range' });
      }
    });
  };
})(jQuery);
