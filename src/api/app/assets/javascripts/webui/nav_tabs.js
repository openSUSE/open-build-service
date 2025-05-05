var HASH_PREFIX = 'tab-pane-';

$(document).ready(function () {
  // Show tab-pane comming from the url hash. If the url hash is empty, show first tab-pane.
  var tabPaneId = document.location.hash.replace('#' + HASH_PREFIX, '#') ||
    $('.nav-tabs:not(.disable-link-generation) .nav-item:first-child .nav-link').attr('href');

  $('.nav-tabs:not(.disable-link-generation) .nav-link[href="' + tabPaneId + '"]').tab('show');

  replaceURLActionHash();

  // Change url hash for page-reload
  $('.nav-tabs:not(.disable-link-generation) .nav-item .nav-link').on('shown.bs.tab', function (event) {
    if ($(event.target).parent('.nav-item').is(':first-child')) {
      window.history.pushState('', document.title, window.location.pathname + window.location.search);
    }
    else {
      document.location.hash = event.target.hash.replace('#', '#' + HASH_PREFIX);
    }
    replaceURLActionHash();

    /*
     * jshint false positive fires an error saying the `setCollapsible` function is not defined
     * actually it is, just in another file (`collapsible_text.js`)
     */
    setCollapsible(); // jshint ignore:line
  });

  function replaceURLActionHash() {
    var buttonToAction = $('.button_to').attr('action');
    if (typeof buttonToAction !== 'undefined') {
      $('.button_to').attr('action', buttonToAction.replace(/#.+/, '') + document.location.hash);
    }
    $('.activity-link').each(function() {
      this.href += document.location.hash;
    });
  }
});
