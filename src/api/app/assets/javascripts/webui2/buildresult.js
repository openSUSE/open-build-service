function updateRpmlintResult(index) { // jshint ignore:line
  $('#rpm'+index+'-reload').addClass('fa-spin');
  $.ajax({
    url: '/package/rpmlint_result',
    data: $('#buildresult' + index + '-box').data(),
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
  var ajaxDataShow = $('#buildresult' + index + '-box').data();
  ajaxDataShow.show_all = $('#show_all_'+index).is(':checked'); // jshint ignore:line
  ajaxDataShow.collapsedRepositories = $('.result div.collapse:not(.show)').map(function(_index, domElement) { return $(domElement).data('repository'); }).get();
  $('#build'+index+'-reload').addClass('fa-spin');
  $.ajax({
    url: $('#buildresult' + index + '-urls').data('buildresultUrl'),
    data: ajaxDataShow,
    success: function(data) {
      $('#build' + index + ' .result').html(data);
    },
    error: function() {
      $('#build' + index + ' .result').html('<p>No build results available</p>');
    },
    complete: function() {
      $('#build' + index + '-reload').removeClass('fa-spin');
      $('[data-toggle="popover"]').popover({ trigger: 'hover click' });
    }
  });
}

// TODO: Handle 'ajax:error', 'ajax:complete' and DRY binding code
function subscribeAjaxEvents(index) {
  $('#show_all_' + index).on('ajax:success', function(_event, data, _status, _xhr) {
    $('#build' + index + ' .result').html(data);
    // Since the element on which we bind this event is rendered again on the line just above, it needs to be bound again...
    subscribeAjaxEvents(index);
  });

  $('button.build-refresh').on('ajax:before', function(_event) {
    var button = $(this);
    var buttonParams = button.data('params');
    console.log(buttonParams);
    // var serializedCollapsedRepositories = $('.result div.collapse:not(.show)').map(function(_index, domElement) { return $.param((({ repository }) => ({ repository }))($(domElement).data())); }).get().join('&');
    // button.data('params', buttonParams + '&' + serializedCollapsedRepositories);
    console.log(button.data);
  });

  // $('button.build-refresh').on('ajax:beforeSend', function(_event, _xhr, settings) {
  //   var button = $(this);
  //   console.log(_event);
  //   console.log(_xhr);
  //   console.log(settings);
  //   button.data('collapsedRepositories', $('.result div.collapse:not(.show)').map(function(_index, domElement) { return $(domElement).data('repository'); }).get());
  //   console.log(button.data());
  // });

  $('button.build-refresh').on('ajax:success', function(_event, data, _status, _xhr) {
    $('#build' + index + ' .result').html(data);
    // Since the element on which we bind this event is rendered again on the line just above, it needs to be bound again...
    subscribeAjaxEvents(index);
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
