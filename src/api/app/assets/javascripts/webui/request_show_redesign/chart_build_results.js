function updateChartBuildResults() {
  $('#chart-build-reload').addClass('fa-spin');
  $.ajax({
    url: $('.chart_build_results_wrapper').data('url'),
    success: function(data) {
      $('.chart_build_results_wrapper').html(data);
    },
    error: function() {
      $('.chart_build_results_wrapper').html('<p>Something went wrong loading the Build Results Chart</p>');
    },
    complete: function() {
      $('#chart-build-reload').removeClass('fa-spin');
    }
  });
}

function linkBuildSummaryChartToBuildResultsTab() { // jshint ignore:line
  var buildResultSummaryChart = Chartkick.charts['build-summary-chart'].getChartObject();

  // If the mouse hovers a data point, let the cursor tell the user it is clickable
  $("#build-summary-chart").on('mousemove', function(e) {
    var points = buildResultSummaryChart.getElementsAtEventForMode(e, 'nearest', { intersect: true }, true);
    $(this).css('cursor', points.length ? 'pointer' : 'default');
  });

  $("#build-summary-chart").click(function(e) {
    var points = buildResultSummaryChart.getElementsAtEventForMode(e, 'nearest', { intersect: true }, true);
    // click was not on a bar in the chart
    if(!points.length) return;

    var repositoryName = buildResultSummaryChart.data.labels[points[0].index];
    var buildState = buildResultSummaryChart.data.datasets[points[0].datasetIndex].label;
    // fetch url of the current request and create the link with the filter parameters
    // to the build result tab
    var requestShowUrl = window.location.pathname;
    var requestBuildResultTabUrl = requestShowUrl + "/build_results" + "?repo_" + repositoryName + "=1" + buildResultStatusFilterQueryParams(buildState);

    window.open(requestBuildResultTabUrl);
  });
}

// the build result summary uses summarized build states, we have to map them back
// to the original build state names in order to apply the filters
function buildResultStatusFilterQueryParams(buildStateFromSummaryChart) {
  switch(buildStateFromSummaryChart) {
    case 'Published':
      return '&status_succeeded=1';
    case 'Failed':
      return '&status_failed=1&status_unresolvable=1&status_broken=1';
    case 'Building':
      return '&status_blocked=1&status_dispatching=1&status_scheduled=1&status_building=1&status_finished=1&status_signing=1&status_locked=1&status_deleting=1&status_unknown=1';
    case 'Excluded':
      return '&status_disabled=1&status_excluded=1';
  }
}
