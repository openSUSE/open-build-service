var hash_prefix = 'tab-pane-';

$(document).ready(function () {
  // Show tab-pane comming from the url hash. If the url hash is empty, show first tab-pane.
  var tab_pane_id = document.location.hash.replace('#' + hash_prefix, '#') || $('.nav-tabs .nav-item:first-child .nav-link').attr('href');
  $('.nav-tabs .nav-link[href="' + tab_pane_id + '"]').tab('show');

  // Change url hash for page-reload
  $('.nav-tabs .nav-item .nav-link').on('shown.bs.tab', function (event) {
    if ($(event.target).parent('.nav-item').is(':first-child')) {
      history.pushState('', document.title, window.location.pathname + window.location.search);
    }
    else {
      document.location.hash = event.target.hash.replace('#', '#' + hash_prefix);
    }
  });
});
