/* ==========================================================================
   CMS · Integrated Mental Health Programme — js/ajax.js
   Global AJAX helper + Select2 remote-data helper.
   Every request shows the global loader; failures toast.

   window.cmsAjax({ url, method, data, success, error, fallbackMsg, json })
   - url        : endpoint (required)
   - method     : 'GET' (default) | 'POST' | 'PUT' | 'DELETE'
   - data       : payload / query params (default {})
   - json       : true → send body as application/json (needed for MVC model
                  binding of complex objects); false → classic form encoding
   - success    : function(response)
   - error      : function(xhr) extra error hook — return true from it to
                  swallow the default error toast
   - fallbackMsg: toast message on failure
   ========================================================================== */
window.cmsAjax = function(o){
  CMS.loader(true);
  var isJson = !!o.json;
  var ajaxOpts = {
    url: o.url,
    method: o.method || 'GET',
    dataType: 'json',
    timeout: 15000,
    headers: { 'X-Requested-With': 'XMLHttpRequest' }
  };
  var csrf = document.querySelector('meta[name="csrf-token"]');
  if (csrf && csrf.content) ajaxOpts.headers['RequestVerificationToken'] = csrf.content;
  if (isJson) {
    ajaxOpts.contentType = 'application/json; charset=utf-8';
    if (o.data !== undefined && o.data !== null &&
        (ajaxOpts.method === 'POST' || ajaxOpts.method === 'PUT' || ajaxOpts.method === 'DELETE')) {
      ajaxOpts.data = JSON.stringify(o.data);
    } else {
      ajaxOpts.data = o.data || {};
    }
  } else {
    ajaxOpts.data = o.data || {};
  }
  $.ajax(ajaxOpts).done(function(res){
    CMS.loader(false);
    if (o.success) o.success(res);
  }).fail(function(xhr){
    CMS.loader(false);
    var handled = o.error ? o.error(xhr) === true : false;
    if (!handled) {
      var msg = o.fallbackMsg;
      if (!msg) {
        if (xhr.status === 401) msg = 'Session expired — please sign in again.';
        else if (xhr.status === 403) msg = 'You do not have permission for this action.';
        else if (xhr.responseJSON && xhr.responseJSON.message) msg = xhr.responseJSON.message;
        else msg = 'Could not reach server.';
      }
      CMS.toast(msg, 'error');
      if (xhr.status === 401 && !/Account\/Login/i.test(location.pathname)) {
        setTimeout(function(){ location.href = '/Account/Login'; }, 900);
      }
    }
  });
};

/**
 * window.cmsSelect2Ajax($el, url, opts)
 * Turns a <select> into a remote-search Select2. Server should return
 * { items: [{id, text|name}] } or a plain array of {id, text|name}.
 */
window.cmsSelect2Ajax = function($el, url, opts){
  $el.select2($.extend({
    width: '100%',
    minimumInputLength: 1,
    ajax: {
      url: url,
      dataType: 'json',
      delay: 250,
      data: function(p){ return { q: p.term }; },
      processResults: function(d){
        return {
          results: $.map(d.items || d, function(it){
            return { text: it.text || it.name, id: it.id };
          })
        };
      }
    }
  }, opts || {}));
};
