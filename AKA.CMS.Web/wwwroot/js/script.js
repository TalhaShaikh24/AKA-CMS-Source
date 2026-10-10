/* ==========================================================================
   CMS · Integrated Mental Health Programme — js/script.js
   Core layout builder, nav, topbar, toasts, demo data and helpers.
   Requires: jQuery 3.x. Loaded by every page.
   ========================================================================== */
window.CMS = window.CMS || {};

/* --------------------------------------------------------------------------
   SVG ICONS (stroke=currentColor, 18x18, minimal paths)
   -------------------------------------------------------------------------- */
CMS.icons = {
  grid:        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>',
  folder:      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>',
  calendar:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4.5" width="18" height="16" rx="2"/><path d="M8 2.5v4M16 2.5v4M3 10h18"/></svg>',
  clipboard:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4a3 3 0 0 1 6 0M9.5 13l2 2 3.5-4"/></svg>',
  shield:      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l7 3v5c0 5-3.5 8.5-7 10-3.5-1.5-7-5-7-10V6z"/><path d="M9.5 12l2 2 3.5-4"/></svg>',
  heart:       '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20.5S4 15.5 4 9.8A4.3 4.3 0 0 1 8.2 5.5c1.7 0 3 .9 3.8 2.3a4.7 4.7 0 0 1 3.8-2.3A4.3 4.3 0 0 1 20 9.8c0 5.7-8 10.7-8 10.7z"/><path d="M7 12h3l1.5-2.5L14 13l1.5-2H18"/></svg>',
  users:       '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.8a3.5 3.5 0 0 1 0 6.4M17.5 14.5a6.5 6.5 0 0 1 4 5.5"/></svg>',
  chart:       '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20V10M10 20V4M16 20v-8M22 20H2"/></svg>',
  gear:        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.87l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.7 1.7 0 0 0-1.87-.34 1.7 1.7 0 0 0-1 1.55V21a2 2 0 1 1-4 0v-.09a1.7 1.7 0 0 0-1-1.55 1.7 1.7 0 0 0-1.87.34l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.7 1.7 0 0 0 .34-1.87 1.7 1.7 0 0 0-1.55-1H3a2 2 0 1 1 0-4h.09a1.7 1.7 0 0 0 1.55-1 1.7 1.7 0 0 0-.34-1.87l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.7 1.7 0 0 0 1.87.34h.09a1.7 1.7 0 0 0 1-1.55V3a2 2 0 1 1 4 0v.09a1.7 1.7 0 0 0 1 1.55 1.7 1.7 0 0 0 1.87-.34l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.7 1.7 0 0 0-.34 1.87v.09a1.7 1.7 0 0 0 1.55 1H21a2 2 0 1 1 0 4h-.09a1.7 1.7 0 0 0-1.55 1z"/></svg>',
  bell:        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 1 0-12 0c0 7-3 8-3 8h18s-3-1-3-8M10.3 21a2 2 0 0 0 3.4 0"/></svg>',
  search:      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
  menu:        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg>'
};

/* --------------------------------------------------------------------------
   NAV DEFINITION
   sections: Main / Care / System
   -------------------------------------------------------------------------- */
CMS.NAV = [
  { key:'dashboard',    label:'Dashboard',      href:'dashboard.html',    icon:'grid',      section:'Main'   },
  { key:'cases',        label:'Cases',          href:'cases.html',        icon:'folder',    section:'Main'   },
  { key:'appointments', label:'Appointments',   href:'appointments.html', icon:'calendar',  section:'Main'   },
  { key:'screening',    label:'Screening',      href:'screening.html',    icon:'clipboard', section:'Main'   },
  { key:'safety-plan',  label:'Safety Plans',   href:'safety-plan.html',  icon:'shield',    section:'Care'   },
  { key:'treatment-plan',label:'Treatment Plans',href:'treatment-plan.html',icon:'heart',   section:'Care'   },
  { key:'users',        label:'Users',          href:'users.html',        icon:'users',     section:'System' },
  { key:'reports',      label:'Reports',        href:'reports.html',      icon:'chart',     section:'System' },
  { key:'settings',     label:'Settings',       href:'settings.html',    icon:'gear',      section:'System' }
];

/* --------------------------------------------------------------------------
   flowerSVG(size) — 8-petal logo, petals alternating light blue / lime on
   dark backgrounds (sidebar, auth) with a lime center.
   -------------------------------------------------------------------------- */
CMS.flowerSVG = function(size){
  size = size || 40;
  var petals = '', i, angle, petal;
  for (i = 0; i < 8; i++){
    angle = i * 45;
    petal = (i % 2 === 0) ? '#DCE88A' : '#A9BEE0';
    petals += '<ellipse cx="50" cy="26" rx="9" ry="19" fill="' + petal + '" transform="rotate(' + angle + ' 50 50)"/>';
  }
  return '<svg class="flower" width="' + size + '" height="' + size + '" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">' +
    petals +
    '<circle cx="50" cy="50" r="10" fill="#DCE88A"/>' +
    '<circle cx="50" cy="50" r="4.5" fill="#2E3D62"/>' +
  '</svg>';
};

/* --------------------------------------------------------------------------
   sidebarHTML(activeKey)
   -------------------------------------------------------------------------- */
CMS.sidebarHTML = function(activeKey){
  var sections = ['Main', 'Care', 'System'], html = '', s, items, item, i;
  for (s = 0; s < sections.length; s++){
    html += '<div class="nav-label">' + sections[s] + '</div>';
    items = $.grep(CMS.NAV, function(n){ return n.section === sections[s]; });
    for (i = 0; i < items.length; i++){
      item = items[i];
      html += '<a href="' + item.href + '" class="nav-link' + (item.key === activeKey ? ' active' : '') + '" data-key="' + item.key + '">' +
        CMS.icons[item.icon] + '<span>' + item.label + '</span></a>';
    }
  }
  return '<aside class="sidebar">' +
    '<div class="brand">' + CMS.flowerSVG(40) +
      '<div><strong>Integrated Mental Health</strong><span>Case Management System</span></div>' +
    '</div>' +
    '<nav class="nav">' + html + '</nav>' +
    '<div class="role-badge"><strong>Ayesha Khan</strong>Psychologist · Full access</div>' +
  '</aside>';
};

/* --------------------------------------------------------------------------
   topbarHTML()
   -------------------------------------------------------------------------- */
CMS.topbarHTML = function(){
  return '<header class="topbar">' +
    '<button class="icon-btn nav-toggle" id="navToggle" aria-label="Menu">' + CMS.icons.menu + '</button>' +
    '<div class="search"><span class="search-ic">' + CMS.icons.search + '</span>' +
      '<input type="text" id="globalSearch" placeholder="Search cases, patients, appointments…">' +
    '</div>' +
    '<div class="topbar-actions">' +
      '<input type="text" class="input cms-daterange" id="topDateRange" placeholder="Last 30 days" readonly>' +
      '<div style="position:relative">' +
        '<button class="icon-btn" id="notifBtn" aria-label="Notifications">' + CMS.icons.bell + '<span class="dot"></span></button>' +
        '<div class="notif-dropdown" id="notifDrop">' +
          '<div class="nd-head"><span>Notifications</span><span class="link">Mark all read</span></div>' +
          '<div class="notif-item"><div class="ni" style="background:var(--pink-tint)">!</div><div><p><strong>Crisis alert</strong> — Imran Khan (CM-2025-000567) flagged for immediate review.</p><div class="t">20 min ago</div></div></div>' +
          '<div class="notif-item"><div class="ni" style="background:var(--peach-tint)">◷</div><div><p><strong>Follow-up due</strong> — Laiba Khan (CM-2025-000124) has a PHQ-9 re-screen tomorrow.</p><div class="t">2h ago</div></div></div>' +
          '<div class="notif-item"><div class="ni" style="background:var(--blue-tint)">+</div><div><p><strong>New case assigned</strong> — Fatima Noor (CM-2025-000342) assigned to Dr. Ahmed Khan.</p><div class="t">Yesterday</div></div></div>' +
        '</div>' +
      '</div>' +
      '<div class="profile"><div class="avatar">' + CMS.initials('Ayesha Khan') + '</div>' +
        '<div><strong>Ayesha Khan</strong><span>Psychologist</span></div>' +
      '</div>' +
    '</div>' +
  '</header>';
};

/* --------------------------------------------------------------------------
   mountLayout(pageKey)
   Pages call: CMS.mountLayout('dashboard') — builds the shell, binds the
   layout, initialises plugins. Page content goes inside #pageContent.
   -------------------------------------------------------------------------- */
CMS.mountLayout = function(pageKey){
  var navItem = $.grep(CMS.NAV, function(n){ return n.key === pageKey; })[0] || { label:'CMS' };
  var $app = $('#app');

  // Detach existing page content (kept by the page author in #pageContent)
  var $page = $('#pageContent').detach();

  $app.empty();
  $app.append(
    CMS.sidebarHTML(pageKey) +
    '<div class="main">' +
      CMS.topbarHTML() +
      '<div class="content" id="contentSlot"></div>' +
    '</div>' +
    '<div class="overlay" id="navOverlay"></div>'
  );
  $('#contentSlot').append($page);

  document.title = navItem.label + ' · CMS — Integrated Mental Health Programme';

  CMS.bindLayout();
  CMS.initSelect2(document);
  CMS.initDateRange(document);
  CMS.initValidation(document);
};

/* --------------------------------------------------------------------------
   bindLayout() — shared interactive behaviour of the shell
   -------------------------------------------------------------------------- */
CMS.bindLayout = function(){
  // Sidebar toggle — desktop: collapse/expand icon-only; mobile: off-canvas drawer
  var isMobile = function(){ return window.matchMedia('(max-width:900px)').matches; };
  var readCollapsed = function(){
    try{ return localStorage.getItem('cms-sidebar-collapsed') === '1'; }catch(e){ return false; }
  };
  var applyCollapsed = function(){
    $('body').toggleClass('sidebar-collapsed', readCollapsed() && !isMobile());
  };
  $('#navToggle').off('click.cmsnav').on('click.cmsnav', function(){
    if (isMobile()){
      $('body').toggleClass('nav-open');
    } else {
      var c = !$('body').hasClass('sidebar-collapsed');
      $('body').toggleClass('sidebar-collapsed', c);
      try{ localStorage.setItem('cms-sidebar-collapsed', c ? '1' : '0'); }catch(e){}
    }
  });
  applyCollapsed();
  $(window).off('resize.cmsnav').on('resize.cmsnav', applyCollapsed);

  // Mobile nav overlay
  $('#navOverlay').off('click.cmsnav').on('click.cmsnav', function(){ $('body').removeClass('nav-open'); });
  $(document).off('keydown.cms').on('keydown.cms', function(e){
    if (e.key === 'Escape'){ $('body').removeClass('nav-open'); $('#notifDrop').removeClass('open'); }
  });

  // Global search → toast on Enter
  $('#globalSearch').off('keypress.cms').on('keypress.cms', function(e){
    if (e.which === 13){
      var q = $.trim($(this).val());
      if (q) CMS.toast("Searching for '" + q + "'…");
    }
  });

  // Notifications dropdown
  $('#notifBtn').off('click.cms').on('click.cms', function(e){
    e.stopPropagation();
    $('#notifDrop').toggleClass('open');
  });
  $(document).off('click.cmsnotif').on('click.cmsnotif', function(e){
    if (!$(e.target).closest('#notifDrop, #notifBtn').length) $('#notifDrop').removeClass('open');
  });
  $('#notifDrop .nd-head .link').on('click', function(){
    $('#notifDrop .notif-item').fadeTo(200, .45);
    $('#notifBtn .dot').hide();
    CMS.toast('All notifications marked as read.', 'success');
  });

  // Generic modal helpers (used by pages)
  $(document).off('click.cmsmodal').on('click.cmsmodal', '[data-modal]', function(){
    $($(this).data('modal')).addClass('open');
  });
  $(document).on('click', '.modal-backdrop', function(e){
    if (e.target === this) $(this).removeClass('open');
  });
  $(document).on('click', '.modal-x, [data-modal-close], [data-close]', function(){
    $(this).closest('.modal-backdrop').removeClass('open');
  });

  // Generic tabs
  $(document).off('click.cmstabs').on('click.cmstabs', '.tab[data-tab]', function(){
    var $tab = $(this), $wrap = $tab.closest('.tabs').parent();
    $wrap.find('.tab').removeClass('active'); $tab.addClass('active');
    $wrap.find('.tab-panel').removeClass('active');
    $wrap.find('#' + $tab.data('tab')).addClass('active');
  });

  // Segmented single-select buttons (used by screening question modals).
  $(document).off('click.cmsseg').on('click.cmsseg', '.seg button', function(){
    var $seg = $(this).closest('.seg');
    $seg.find('button').removeClass('sel');
    $(this).addClass('sel');
    $seg.closest('.field').removeClass('invalid');
  });
};

/* --------------------------------------------------------------------------
   toast(msg, type) — the global notification function.
   Usage: CMS.toast('Case saved.', 'success');
   type: 'info' (default) | 'success' | 'warning' | 'error'
   The message is HTML-escaped, so it is safe to pass server text.
   -------------------------------------------------------------------------- */
CMS.toast = function(msg, type){
  type = ['info', 'success', 'warning', 'error'].indexOf(type) >= 0 ? type : 'info';
  var $wrap = $('.toast-wrap');
  if (!$wrap.length){ $wrap = $('<div class="toast-wrap"></div>').appendTo('body'); }
  // Keep the stack readable: drop the oldest when more than 4 are showing.
  while ($wrap.children('.toast').length >= 4){ $wrap.children('.toast').first().remove(); }
  var $t = $('<div class="toast"></div>').addClass(type).text(msg == null ? '' : String(msg));
  $wrap.append($t);
  setTimeout(function(){ $t.fadeOut(300, function(){ $t.remove(); }); }, 3600);
};

/* --------------------------------------------------------------------------
   loader(show)
   -------------------------------------------------------------------------- */
CMS.loader = function(show){
  var $l = $('.loader');
  if (!$l.length){ $l = $('<div class="loader"><div class="spinner"></div></div>').appendTo('body'); }
  $l.toggleClass('show', !!show);
};

/* ==========================================================================
   DEMO DATA
   ========================================================================== */
CMS.demo = {};

CMS.demo.cases = [
  {id:'CM-2025-000567',name:'Imran Khan',age:32,gender:'Male',location:'Skardu',risk:'crisis',status:'Active',assignee:'Ayesha Khan',updated:'2h ago'},
  {id:'CM-2025-000123',name:'Sana Khan',age:16,gender:'Female',location:'Gojal',risk:'high',status:'Active',assignee:'Dr. Ahmed Khan',updated:'5h ago'},
  {id:'CM-2025-000231',name:'Ali Raza',age:28,gender:'Male',location:'Hunza',risk:'moderate',status:'Active',assignee:'Ayesha Khan',updated:'1d ago'},
  {id:'CM-2025-000453',name:'Sana Gul',age:19,gender:'Female',location:'Ghizer',risk:'low',status:'New',assignee:'Bilal Ahmed',updated:'1d ago'},
  {id:'CM-2025-000124',name:'Laiba Khan',age:16,gender:'Female',location:'Booni',risk:'moderate',status:'Follow-up Due',assignee:'Ayesha Khan',updated:'2d ago'},
  {id:'CM-2025-000342',name:'Fatima Noor',age:24,gender:'Female',location:'Skardu',risk:'high',status:'New',assignee:'Dr. Ahmed Khan',updated:'2d ago'},
  {id:'CM-2025-000289',name:'Hassan Ali',age:41,gender:'Male',location:'Hunza',risk:'low',status:'Active',assignee:'Bilal Ahmed',updated:'3d ago'},
  {id:'CM-2025-000511',name:'Maria Bibi',age:35,gender:'Female',location:'Ghizer',risk:'moderate',status:'LTFU',assignee:'Ayesha Khan',updated:'5d ago'},
  {id:'CM-2025-000098',name:'Usman Tariq',age:22,gender:'Male',location:'Gojal',risk:'crisis',status:'Follow-up Due',assignee:'Dr. Ahmed Khan',updated:'1w ago'},
  {id:'CM-2025-000476',name:'Nadia Hussain',age:29,gender:'Female',location:'Booni',risk:'low',status:'New',assignee:'Bilal Ahmed',updated:'1w ago'},
  {id:'CM-2025-000633',name:'Kamran Shah',age:38,gender:'Male',location:'Skardu',risk:'moderate',status:'Active',assignee:'Ayesha Khan',updated:'1w ago'},
  {id:'CM-2025-000187',name:'Amina Wali',age:21,gender:'Female',location:'Hunza',risk:'high',status:'Active',assignee:'Dr. Ahmed Khan',updated:'2w ago'}
];

CMS.demo.appointments = [
  {patient:'Sana Khan',caseId:'CM-2025-000123',date:'2026-09-25',time:'10:00 AM',type:'Psychological Session',mode:'Teleconsultation',location:'Counseling Room 1'},
  {patient:'Imran Khan',caseId:'CM-2025-000567',date:'2026-09-25',time:'11:30 AM',type:'Crisis Review',mode:'In-person',location:'Counseling Room 2'},
  {patient:'Ali Raza',caseId:'CM-2025-000231',date:'2026-09-26',time:'09:00 AM',type:'Follow-up',mode:'In-person',location:'Counseling Room 1'},
  {patient:'Fatima Noor',caseId:'CM-2025-000342',date:'2026-09-26',time:'02:00 PM',type:'Intake Assessment',mode:'Teleconsultation',location:'—'},
  {patient:'Usman Tariq',caseId:'CM-2025-000098',date:'2026-09-27',time:'10:30 AM',type:'Safety Plan Review',mode:'In-person',location:'Counseling Room 2'},
  {patient:'Laiba Khan',caseId:'CM-2025-000124',date:'2026-09-28',time:'12:00 PM',type:'Family Session',mode:'In-person',location:'Counseling Room 1'}
];

CMS.demo.users = [
  {name:'Ayesha Khan',email:'ayesha.khan@cmhs.pk',role:'Psychologist',status:'Active',caseCount:48},
  {name:'Dr. Ahmed Khan',email:'ahmed.khan@cmhs.pk',role:'GP',status:'Active',caseCount:35},
  {name:'Bilal Ahmed',email:'bilal.ahmed@cmhs.pk',role:'CMO',status:'Active',caseCount:52},
  {name:'Sara Malik',email:'sara.malik@cmhs.pk',role:'Health Promoter',status:'Active',caseCount:61},
  {name:'Dr. Sana Iqbal',email:'sana.iqbal@cmhs.pk',role:'Psychiatrist',status:'On Leave',caseCount:12},
  {name:'Kamran Yusuf',email:'kamran.y@cmhs.pk',role:'Data Entry',status:'Inactive',caseCount:0}
];

CMS.demo.trend = {
  labels:['Apr','May','Jun','Jul','Aug','Sep'],
  cases:[42,55,48,63,71,58],
  screenings:[38,47,52,60,66,61]
};

CMS.demo.riskDist = {
  labels:['Low','Moderate','High','Crisis'],
  data:[86,64,42,18],
  colors:['#2F9E63','#D99413','#E0652B','#D64545']
};

CMS.demo.monthly = CMS.demo.trend.cases.slice();

CMS.demo.followups = [
  {patient:'Laiba Khan',caseId:'CM-2025-000124',due:'Tomorrow',type:'PHQ-9 Re-screen'},
  {patient:'Usman Tariq',caseId:'CM-2025-000098',due:'In 2 days',type:'Safety Plan Review'},
  {patient:'Imran Khan',caseId:'CM-2025-000567',due:'In 3 days',type:'Crisis Follow-up'},
  {patient:'Sana Khan',caseId:'CM-2025-000123',due:'Next week',type:'Therapy Session'}
];

/* ==========================================================================
   HELPERS
   ========================================================================== */

/* riskBadge('crisis') → <span class="badge badge-crisis">Crisis</span> */
CMS.riskBadge = function(r){
  r = (r || 'low').toLowerCase();
  var label = r.charAt(0).toUpperCase() + r.slice(1);
  return '<span class="badge badge-' + r + '">' + label + '</span>';
};

/* statusPill('Follow-up Due') → <span class="badge st-followup">Follow-up Due</span> */
CMS.statusPill = function(s){
  var map = {'New':'st-new','Active':'st-active','Follow-up Due':'st-followup','LTFU':'st-ltfu'};
  var cls = map[s] || 'st-ltfu';
  return '<span class="badge ' + cls + '">' + s + '</span>';
};

/* initials('Ayesha Khan') → 'AK' */
CMS.initials = function(name){
  return $.map((name || '').split(' '), function(w){ return w.charAt(0); })
    .join('').substring(0, 2).toUpperCase();
};

/* todayStr() → '24 Sep 2026' */
CMS.todayStr = function(){
  return '24 Sep 2026';
};

/* --------------------------------------------------------------------------
   initSelect2(scope) — upgrades <select class="select2"> (Select2 must be
   loaded by the page; skipped silently otherwise)
   -------------------------------------------------------------------------- */
CMS.initSelect2 = function(scope){
  if (!$.fn.select2) return;
  $(scope).find('select.select2').each(function(){
    var $s = $(this);
    if ($s.data('select2')) return;
    // Render the dropdown inside a modal when the select lives in one, so the
    // popup can't be clipped or push page layout (prevents scrollbar flicker).
    var $modal = $s.closest('.modal');
    var opts = {
      width:'100%',
      placeholder: $s.attr('placeholder') || 'Select…',
      allowClear: !!$s.data('allow-clear')
    };
    if ($modal.length) opts.dropdownParent = $modal;
    $s.select2(opts);
  });
};

/* --------------------------------------------------------------------------
   initDateRange(scope) — .cms-daterange → range picker, .cms-date → single.
   Plugin defined in js/daterange-picker.js; skipped if not loaded.
   -------------------------------------------------------------------------- */
CMS.initDateRange = function(scope){
  if (!$.fn.cmsDateRange) return;
  $(scope).find('input.cms-daterange').each(function(){
    var $i = $(this);
    if (!$i.data('cmsdr')) $i.cmsDateRange({ mode:'range' });
  });
  $(scope).find('input.cms-date').each(function(){
    var $i = $(this);
    if (!$i.data('cmsdr')) $i.cmsDateRange({ mode:'single' });
  });
};

/* --------------------------------------------------------------------------
   initValidation(scope) — binds forms[data-validate]. Plugin in
   js/validation.js; skipped if not loaded.
   -------------------------------------------------------------------------- */
CMS.initValidation = function(scope){
  if (!$.fn.cmsValidate) return;
  $(scope).find('form[data-validate]').cmsValidate();
};
