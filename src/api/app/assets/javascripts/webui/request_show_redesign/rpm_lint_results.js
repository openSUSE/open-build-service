// TODO: rename without "Beta" after the rollout of 'request_show_redesign'.
function updateRpmLintResultBeta() { // jshint ignore:line
  var ajaxDataShow = $('.rpm-lint-results-content').data();
  var rpmLintResultsUrl = $('.rpm-lint-results-content .rpm-lint-refresh').data('rpm-lint-results-url');

  $('#rpm-lint-reload').addClass('fa-spin');
  $.ajax({
    url: rpmLintResultsUrl,
    data: ajaxDataShow,
    success: function(data) {
      $('.rpm-lint-results-content .result').html(data);
    },
    error: function() {
      $('.rpm-lint-results-content .result').html('<p>No RPM lint results available</p>');
    },
    complete: function() {
      $('#rpm-lint-reload').removeClass('fa-spin');
      initializePopovers('[data-toggle="popover"]'); // jshint ignore:line
    }
  });
}
