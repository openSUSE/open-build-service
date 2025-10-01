// TODO: rename without "Beta" after the rollout of 'request_show_redesign'.
function updateBuildResultBeta() { // jshint ignore:line
  var buildResultsUrl = $('.build-results-content .result').data('build-results-url');

  $('#build-reload').addClass('fa-spin');
  $.ajax({
    url: buildResultsUrl,
    data: Object.fromEntries(new URLSearchParams(location.search)), // jshint ignore:line
    success: function(data) {
      $('.build-results-content .result').html(data);
    },
    error: function() {
      $('.build-results-content .result').html('<p>No build results available</p>');
    },
    complete: function() {
      $('#build-reload').removeClass('fa-spin');
      setupDropdownFilters(); // jshint ignore:line
    }
  });
}
