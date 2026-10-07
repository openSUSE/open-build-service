/* exported updateBuildResult */
/* global initializePopovers */

function updateBuildResult(index) {
  var collapsedPackages = [];
  var collapsedRepositories = {};
  $('.result div.collapse:not(.show)').map(function(_index, domElement) {
    var main = $(domElement).data('main') ? $(domElement).data('main') : 'project';
    if (collapsedRepositories[main] === undefined) { collapsedRepositories[main] = []; }
    if ($(domElement).data('repository') === undefined) {
      collapsedPackages.push(main);
    }
    else {
      collapsedRepositories[main].push($(domElement).data('repository'));
    }
  });

  var ajaxDataShow = $('#buildresult' + index + '-box').data();
  ajaxDataShow.show_all = $('#show_all_'+index).is(':checked'); // jshint ignore:line
  ajaxDataShow.collapsedPackages = collapsedPackages;
  ajaxDataShow.collapsedRepositories = collapsedRepositories;
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
