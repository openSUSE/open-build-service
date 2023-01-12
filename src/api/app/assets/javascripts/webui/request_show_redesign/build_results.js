// TODO: rename without "Beta" after the rollout of 'request_show_redesign'.
function updateBuildResultBeta() { // jshint ignore:line
  var ajaxDataShow = $('.build-results-content').data();
  // show_all comes from the buildstatus partial
  ajaxDataShow.show_all = $('#show_all').is(':checked'); // jshint ignore:line
  ajaxDataShow.inRequestShowRedesign = true;

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
      initializePopovers('[data-bs-toggle="popover"]'); // jshint ignore:line
    }
  });
}
