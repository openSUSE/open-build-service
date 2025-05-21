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
  ajaxDataShow.renderChart = true;
  $.ajax({
    url: '/package/rpmlint_log',
    data: ajaxDataShow,
    success: function (data) {
      $('.rpmlint-result').html(data);
    },
    error: function (jqXHR, textStatus, errorThrown) {
      $('.rpmlint-result').html('<p class="error">Error loading rpmlint log (' + errorThrown + ')</p>');
    }
  });
}
