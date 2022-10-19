// TODO: rename without "Beta" after the rollout of 'request_show_redesign'.
function updateBuildResultBeta() { // jshint ignore:line
  var collapsedPackages = [];
  var collapsedRepositories = {};
  $('.result div.collapse:not(.show)').map(function(_index, domElement) {
    var main = $(domElement).data('main') ? $(domElement).data('main') : 'project';
    if (collapsedRepositories[main] === undefined) { collapsedRepositories[main] = []; }
    if ($(domElement).data('repository') === undefined) {
      collapsedPackages.push(main);
    }
    else {
      collapsedRepositories[main].push($(domElement).data('repository'));
    }
  });

  var ajaxDataShow = $('.build-results-content').data();
  // show_all comes from the buildstatus partial
  ajaxDataShow.show_all = $('#show_all').is(':checked'); // jshint ignore:line
  ajaxDataShow.inRequestShowRedesign = true;
  ajaxDataShow.collapsedPackages = collapsedPackages;
  ajaxDataShow.collapsedRepositories = collapsedRepositories;

  var buildResultsUrl = $('.build-results-content .build-refresh').data('build-results-url');

  $('#build-reload').addClass('fa-spin');
  $.ajax({
    url: buildResultsUrl,
    data: ajaxDataShow,
    success: function(data) {
      $('.build-results-content .result').html(data);
    },
    error: function() {
      $('.build-results-content .result').html('<p>No build results available</p>');
    },
    complete: function() {
      $('#build-reload').removeClass('fa-spin');
      initializePopovers('[data-toggle="popover"]'); // jshint ignore:line
    }
  });
}
