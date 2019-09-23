/* global initializePopovers */

// eslint-disable-next-line no-unused-vars
function updateRpmlintResult(index) {
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

// eslint-disable-next-line no-unused-vars
function updateBuildResult(index) {
  var elements = {};
  $('.result div.collapse:not(.show)').map(function(_index, domElement) {
    var main = $(domElement).data('main') ? $(domElement).data('main') : 'project';
    if (elements[main] === undefined) { elements[main] = []; }
    elements[main].push($(domElement).data('repository'));
  });

  var ajaxDataShow = $('#buildresult' + index + '-box').data();
  ajaxDataShow.show_all = $('#show_all_'+index).is(':checked');
  ajaxDataShow.collapsedRepositories = elements;
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
      initializePopovers('[data-toggle="popover"]');
    }
  });
}

// eslint-disable-next-line no-unused-vars
function updateArchDisplay(index) {
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
