function updateRpmlintResult(index) { // jshint ignore:line
  $('#rpm'+index+'-reload').addClass('fa-spin');
  $.ajax({
    url: '/package/rpmlint_result',
    data: $('#buildresult-box').data(),
    success: function(data) {
      $('#rpm' + index + ' .result').html(data);
    },
    error: function() {
      $('#rpm'+ index + ' .result').html('<p>No rpmlint results available</p>');
    },
    complete: function() {
      $('#rpm' + index + '-reload').removeClass('fa-spin');
    }
  });
}

function updateBuildResult(index) { // jshint ignore:line
  var ajaxDataShow = $('#buildresult-box').data();
  ajaxDataShow.show_all = $('#show_all_'+index).is(':checked'); // jshint ignore:line
  $('#build'+index+'-reload').addClass('fa-spin');
  $.ajax({
    url: $('#buildresult-urls').data('buildresultUrl'),
    data: ajaxDataShow,
    success: function(data) {
      $('#build' + index + ' .result').html(data);
    },
    error: function() {
      $('#build' + index + ' .result').html('<p>No build results available</p>');
    },
    complete: function() {
      $('#build' + index + '-reload').removeClass('fa-spin');
      $('[data-toggle="popover"]').popover({ trigger: 'hover' });
    }
  });
}

function updateArchDisplay(index) { // jshint ignore:line
  $('.rpmlint_arch_select_' + index).hide();
  $('#rpmlint_arch_select_' + index + '_' + $('#rpmlint_repo_select_' + index + ' option:selected').attr('value')).show();
  updateRpmlintDisplay(index);
}

function updateRpmlintDisplay(index) {
  var ajaxDataShow = $('#rpmlin-log-' + index).data();
  var repoKey = $('#rpmlint_repo_select_' + index + ' option:selected').attr('value');
  ajaxDataShow.repository = $('#rpmlint_repo_select_' + index + ' option:selected').html();
  ajaxDataShow.architecture = $('#rpmlint_arch_select_' + index + '_' + repoKey + ' option:selected').attr('value');
  $.ajax({
    url: '/package/rpmlint_log',
    data: ajaxDataShow,
    success: function (data) {
      $('#rpmlint_display_' + index).html(data);
    }
  });
}
