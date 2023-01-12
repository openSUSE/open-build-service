// TODO: rename without "Beta" after the rollout of 'request_show_redesign'.
function updateRpmLintResultBeta() { // jshint ignore:line
  var ajaxDataShow = $('.rpm-lint-content').data();
  ajaxDataShow.inRequestShowRedesign = true;
  var rpmLintResultsUrl = $('.rpm-lint-content .rpm-lint-refresh').data('rpm-lint-results-url');

  $('#rpm-lint-reload').addClass('fa-spin');
  $.ajax({
    url: rpmLintResultsUrl,
    data: ajaxDataShow,
    success: function(data) {
      $('.rpm-lint-content .result').html(data);
    },
    error: function() {
      $('.rpm-lint-content .result').html('<p>No RPM lint results available</p>');
    },
    complete: function() {
      $('#rpm-lint-reload').removeClass('fa-spin');
      initializePopovers('[data-bs-toggle="popover"]'); // jshint ignore:line
    }
  });
}

function updateRpmLintArchitectures() { // jshint ignore:line
  $('.rpmlint_arch_select').hide();
  $('#rpmlint_arch_select_' + $('#rpmlint_repo_select option:selected').attr('value')).show();
  updateRpmLintLog();
}


function updateRpmLintLog() {
  var ajaxDataShow = $('#rpmlint-log').data();
  var repoKey = $('#rpmlint_repo_select option:selected').attr('value');
  ajaxDataShow.repository = $('#rpmlint_repo_select option:selected').html();
  ajaxDataShow.architecture = $('#rpmlint_arch_select_' + repoKey + ' option:selected').attr('value');
  $.ajax({
    url: '/package/rpmlint_log',
    data: ajaxDataShow,
    success: function (data) {
      $('.rpmlint-result').html(data);
    }
  });
}
