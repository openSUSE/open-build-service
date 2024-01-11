// TODO: rename without "Beta" after the rollout of 'request_show_redesign'.
function updateBuildResultBeta() { // jshint ignore:line
  var ajaxDataShow = $('.build-results-content').data();
  var buildResultsUrl = $('.build-results-content .result').data('build-results-url');

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
