(function () {
  var buttons = document.querySelectorAll('.lang button');
  function setLang(lang) {
    document.documentElement.lang = lang;
    document.querySelectorAll('[data-en]').forEach(function (el) { el.hidden = lang !== 'en'; });
    document.querySelectorAll('[data-es]').forEach(function (el) { el.hidden = lang !== 'es'; });
    buttons.forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.lang === lang)); });
    try { localStorage.setItem('lang', lang); } catch (e) {}
    tick();
  }
  buttons.forEach(function (b) { b.addEventListener('click', function () { setLang(b.dataset.lang); }); });
  var saved = null;
  try { saved = localStorage.getItem('lang'); } catch (e) {}

  // The menu bar's clock and day box are real, so the demo reads as today's menu bar.
  function tick() {
    var now = new Date();
    var lang = document.documentElement.lang === 'es' ? 'es' : 'en';
    document.querySelectorAll('.daybox').forEach(function (el) { el.textContent = String(now.getDate()); });
    document.querySelectorAll('.clock').forEach(function (el) {
      el.textContent = now.toLocaleDateString(lang, { weekday: 'short', day: 'numeric', month: 'short' })
        + '  ' + now.toLocaleTimeString(lang, { hour: 'numeric', minute: '2-digit' });
    });
  }
  setLang(saved || (navigator.language && navigator.language.indexOf('es') === 0 ? 'es' : 'en'));
  setInterval(tick, 30000);

  // Latest version number, purely cosmetic; the Download link works without it.
  fetch('https://api.github.com/repos/hercase/calenbar/releases/latest')
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (release) {
      if (!release || !release.tag_name) return;
      var v = release.tag_name.replace(/^v/, '');
      document.querySelectorAll('[data-version]').forEach(function (el) {
        el.textContent = (el.dataset.version === 'es' ? ' Versión ' : ' Version ') + v + '.';
      });
    })
    .catch(function () {});
})();
