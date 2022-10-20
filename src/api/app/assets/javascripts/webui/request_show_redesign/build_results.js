// TODO: rename without "Beta" after the rollout of 'request_show_redesign'.
function updateBuildResultBeta() { // jshint ignore:line
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

  var ajaxDataShow = $('.build-results-content').data();
  // show_all comes from the buildstatus partial
  ajaxDataShow.show_all = $('#show_all').is(':checked'); // jshint ignore:line
  ajaxDataShow.collapsedPackages = collapsedPackages;
  ajaxDataShow.collapsedRepositories = collapsedRepositories;

  var buildResultsUrl = $('.build-results-content .build-refresh').data('build-results-url');

  $('#build-reload').addClass('fa-spin');
  $.ajax({
    url: buildResultsUrl,
    data: ajaxDataShow,
    success: function(data) {
      $('.build-results-content .result').html(data);
    },
    error: function() {
      $('.build-results-content .result').html('<p>No build results available</p>');
    },
    complete: function() {
      $('#build-reload').removeClass('fa-spin');
      initializePopovers('[data-toggle="popover"]'); // jshint ignore:line
    }
  });
}

function toggleBuildInfoBeta() { // jshint ignore:line
  $('.toggle-build-info').on('click', function(){
    var replaceTitle = $(this).attr('title') === 'Click to keep it open' ? 'Click to close it' : 'Click to keep it open';
    var infoContainer = $(this).parents('.toggle-build-info-parent').next();
    $(infoContainer).toggleClass('collapsed');
    $(infoContainer).removeClass('hover');
    $('.toggle-build-info').attr('title', replaceTitle);
  });
  $('.toggle-build-info').on('mouseover', function(){
    $(this).parents('.toggle-build-info-parent').next().addClass('hover');
  });
  $('.toggle-build-info').on('mouseout', function(){
    $(this).parents('.toggle-build-info-parent').next().removeClass('hover');
  });
}
