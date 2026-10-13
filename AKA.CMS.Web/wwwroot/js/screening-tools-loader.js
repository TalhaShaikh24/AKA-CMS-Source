/* Shared dynamic screening tool loader.
   Fetches tools + questions from /api/screening-tools/active.
   Falls back to the hardcoded bank (screening-questions.js) if the API fails.
   Usage:
     CMS_SCREEN_TOOLS.load(function(tools) {
       // tools: [{code, name, desc, questions:[{text, options:[{t,v}]}]}]
     });
*/
(function (global) {
  'use strict';

  var cache = null;

  function fromApi(done) {
    if (typeof cmsAjax !== 'function') { fromFallback(done); return; }
    cmsAjax({
      url: '/api/screening-tools/active', method: 'GET',
      fallbackMsg: 'Could not load screening tools.',
      success: function (res) {
        var tools = (res || []).map(function (t) {
          var qs = [];
          try { qs = JSON.parse(t.questionsJson || '[]'); } catch (e) { qs = []; }
          return {
            code: t.toolCode,
            name: t.toolName,
            desc: t.description || '',
            questions: qs.map(function (q) {
              return { text: q.text, options: (q.options || []).map(function (o) { return { t: o.t, v: o.v }; }) };
            })
          };
        });
        cache = tools;
        // Keep the legacy global in sync for older code paths.
        var legacy = {};
        tools.forEach(function (t) { legacy[t.code] = t.questions; });
        global.CMS_SCREEN_QUESTIONS = legacy;
        done(tools);
      },
      error: function () { fromFallback(done); }
    });
  }

  function fromFallback(done) {
    var bank = global.CMS_SCREEN_QUESTIONS || {};
    var names = { PHQ9: ['PHQ-9', 'Depression'], GAD7: ['GAD-7', 'Anxiety'], DASS21: ['DASS-21', 'Stress / Depression / Anxiety'], SBQR: ['SBQ-R', 'Suicide Risk'], CSSRS: ['C-SSRS', 'Suicidal Ideation / Behavior'] };
    var tools = Object.keys(bank).map(function (code) {
      var n = names[code] || [code, ''];
      return { code: code, name: n[0], desc: n[1], questions: bank[code] };
    });
    cache = tools;
    done(tools);
  }

  global.CMS_SCREEN_TOOLS = {
    load: function (done) {
      if (cache) { done(cache); return; }
      fromApi(done);
    },
    clear: function () { cache = null; }
  };
})(window);
