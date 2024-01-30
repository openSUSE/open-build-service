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
