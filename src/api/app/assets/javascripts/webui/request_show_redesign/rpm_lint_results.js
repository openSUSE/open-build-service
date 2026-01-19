/* exported updateRpmLintArchitectures */

function updateRpmLintArchitectures() {
  $('.rpmlint_arch_select').hide();
  $('#rpmlint_arch_select_' + $('#rpmlint_repo_select option:selected').attr('value')).show();
  updateRpmLintLog();
}


function updateRpmLintLog() {
  var repoKey = $('#rpmlint_repo_select option:selected').attr('value');
  var ajaxDataShow = {};
  ajaxDataShow.repository = $('#rpmlint_repo_select option:selected').html();
  ajaxDataShow.architecture = $('#rpmlint_arch_select_' + repoKey + ' option:selected').attr('value');
  ajaxDataShow.renderChart = true;
  $.ajax({
    url: '/package/rpmlint_log/' + $('#rpmlint-log').data('project') + '/' + $('#rpmlint-log').data('package'),
    data: ajaxDataShow,
    success: function (data) {
      $('.rpmlint-result').html(data);
    },
    error: function (jqXHR, textStatus, errorThrown) {
      $('.rpmlint-result').html('<p class="error">Error loading rpmlint log (' + errorThrown + ')</p>');
    }
  });
}

$(document).on('mouseenter', '.lint-description', function() {
  $(this).tooltip({
    container: 'body',
    trigger: 'hover'
  }).tooltip('show');
});
