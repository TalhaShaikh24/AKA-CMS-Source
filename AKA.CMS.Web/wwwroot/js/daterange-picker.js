/* ==========================================================================
   CMS · Integrated Mental Health Programme — js/daterange-picker.js
   $.fn.cmsDateRange — beautified calendar popup, no external dependencies.
   --------------------------------------------------------------------------
   Usage:
     $('input.cms-daterange').cmsDateRange({ mode:'range' });   // default
     $('input.cms-date').cmsDateRange({ mode:'single' });
     $('.my-input').cmsDateRange({ mode:'range', onSelect:function(start,end){} });

   Range mode  → '01 Sep 2026 – 24 Sep 2026'
   Single mode → '24 Sep 2026'
   Popup: rounded 16px panel, month grid, navy selected day, lime range
   background (styled in css/style.css via .cms-dr-picker). Closes on
   outside click / Escape / Apply / Cancel. Positioned under the input.
   ========================================================================== */

(function($){
  'use strict';

  var MONTHS = ['January','February','March','April','May','June','July',
                'August','September','October','November','December'];
  var MONTH_S = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  var DOW = ['Su','Mo','Tu','We','Th','Fr','Sa'];

  var openPicker = null;   // currently open picker instance

  function fmt(d){
    return d.getDate() + ' ' + MONTH_S[d.getMonth()] + ' ' + d.getFullYear();
  }
  function sameDay(a, b){
    return a && b && a.getFullYear() === b.getFullYear() &&
           a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }

  function closeOpen(){
    if (openPicker){ openPicker.close(); openPicker = null; }
  }

  $(document).on('mousedown.cmsdr', function(e){
    if (openPicker && !$(e.target).closest('.cms-dr-picker').length &&
        !$(e.target).closest(openPicker.$input).length){
      closeOpen();
    }
  });
  $(document).on('keydown.cmsdr', function(e){
    if (e.key === 'Escape') closeOpen();
  });

  $.fn.cmsDateRange = function(opts){
    var settings = $.extend({ mode:'range', onSelect:null }, opts || {});

    return this.each(function(){
      var $input = $(this);
      if ($input.data('cmsdr')) return;           // already initialised
      $input.data('cmsdr', true).attr('readonly', true);

      var inst = {
        $input: $input,
        mode: settings.mode === 'single' ? 'single' : 'range',
        view: (function(){ var n = new Date(); n.setDate(1); return n; })(),
        start: null, end: null,
        $panel: null
      };

      /* ---- build panel ---- */
      inst.$panel = $(
        '<div class="cms-dr-picker">' +
          '<div class="cms-dr-head">' +
            '<button type="button" class="cms-dr-nav" data-nav="-1" aria-label="Previous month">&#8249;</button>' +
            '<div class="m"></div>' +
            '<button type="button" class="cms-dr-nav" data-nav="1" aria-label="Next month">&#8250;</button>' +
          '</div>' +
          '<div class="cms-dr-week">' + $.map(DOW, function(d){ return '<div>' + d + '</div>'; }).join('') + '</div>' +
          '<div class="cms-dr-days"></div>' +
          '<div class="cms-dr-foot">' +
            '<button type="button" class="btn btn-ghost btn-sm" data-act="cancel">Cancel</button>' +
            '<button type="button" class="btn btn-primary btn-sm" data-act="apply">Apply</button>' +
          '</div>' +
        '</div>'
      ).appendTo('body');

      if (inst.mode === 'single') inst.$panel.find('.cms-dr-foot').hide();

      /* ---- render month grid ---- */
      function render(){
        var v = inst.view, y = v.getFullYear(), m = v.getMonth();
        inst.$panel.find('.m').text(MONTHS[m] + ' ' + y);

        var first = new Date(y, m, 1).getDay(),
            days = new Date(y, m + 1, 0).getDate(),
            today = new Date(),
            html = '', i, d;

        for (i = 0; i < first; i++) html += '<button type="button" class="cms-dr-day dim" disabled></button>';

        for (i = 1; i <= days; i++){
          d = new Date(y, m, i);
          var cls = 'cms-dr-day';
          if (sameDay(d, today)) cls += ' today';
          if (inst.mode === 'single' && sameDay(d, inst.start)) cls += ' sel';
          if (inst.mode === 'range'){
            if (inst.start && sameDay(d, inst.start)) cls += ' range-start';
            if (inst.end && sameDay(d, inst.end)) cls += ' range-end';
            if (inst.start && inst.end && d > inst.start && d < inst.end) cls += ' in-range';
            if (inst.start && !inst.end && sameDay(d, inst.start)) cls += ' sel';
          }
          html += '<button type="button" class="' + cls + '" data-day="' + i + '">' + i + '</button>';
        }
        inst.$panel.find('.cms-dr-days').html(html);
      }

      /* ---- hover preview for range ---- */
      inst.$panel.on('mouseenter', '.cms-dr-day[data-day]', function(){
        if (inst.mode !== 'range' || !inst.start || inst.end) return;
        var hover = new Date(inst.view.getFullYear(), inst.view.getMonth(), +$(this).data('day'));
        inst.$panel.find('.cms-dr-day[data-day]').each(function(){
          var d = new Date(inst.view.getFullYear(), inst.view.getMonth(), +$(this).data('day'));
          $(this).toggleClass('in-range',
            d > Math.min(inst.start, hover) && d < Math.max(inst.start, hover));
        });
      });

      /* ---- day click ---- */
      inst.$panel.on('click', '.cms-dr-day[data-day]', function(){
        var d = new Date(inst.view.getFullYear(), inst.view.getMonth(), +$(this).data('day'));

        if (inst.mode === 'single'){
          inst.start = d; inst.end = null;
          inst.commit();
          inst.close(); openPicker = null;
          return;
        }
        // range: click sets start, then end; third click restarts
        if (!inst.start || (inst.start && inst.end)){
          inst.start = d; inst.end = null;
        } else if (d < inst.start){
          inst.end = inst.start; inst.start = d;
        } else {
          inst.end = d;
        }
        render();
      });

      /* ---- nav / apply / cancel ---- */
      inst.$panel.on('click', '[data-nav]', function(){
        inst.view.setMonth(inst.view.getMonth() + +$(this).data('nav'));
        render();
      });
      inst.$panel.on('click', '[data-act="cancel"]', function(){ closeOpen(); });
      inst.$panel.on('click', '[data-act="apply"]', function(){
        if (inst.start && !inst.end) inst.end = new Date(inst.start); // single-day range
        inst.commit(); closeOpen();
      });

      /* ---- commit value to the input ---- */
      inst.commit = function(){
        var label = '';
        if (inst.start) label = inst.mode === 'single' ? fmt(inst.start)
                                                      : fmt(inst.start) + ' – ' + fmt(inst.end || inst.start);
        $input.val(label).trigger('change');
        if (settings.onSelect) settings.onSelect(inst.start, inst.end);
      };

      inst.open = function(){
        closeOpen();
        render();
        var o = $input.offset();
        inst.$panel.addClass('open').css({
          top: (o.top + $input.outerHeight() + 8) + 'px',
          left: Math.max(8, Math.min(o.left, $(window).width() - 340)) + 'px'
        });
        openPicker = inst;
      };
      inst.close = function(){ inst.$panel.removeClass('open'); };

      $input.on('click focus', function(){ inst.open(); });

      $input.data('cmsdr-inst', inst);
    });
  };
})(jQuery);
