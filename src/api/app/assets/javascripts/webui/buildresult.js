// TODO: replace with the content of
// app/assets/javascripts/webui/request_show_redesign/build_results.js
// after the rollout of 'request_show_redesign'.

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
      initializePopovers('[data-toggle="popover"]'); // jshint ignore:line
    }
  });
}

function updateArchDisplay(index) { // jshint ignore:line
  $('.rpmlint_arch_select_' + index).hide();
  $('select[name="rpmlint_arch_select_' + index + '_' + $('#rpmlint_repo_select_' + index + ' option:selected').attr('value') + '"]').show();
  updateRpmlintDisplay(index);
}

function updateRpmlintDisplay(index) {
  var ajaxDataShow = $('#rpmlin-log-' + index).data();
  var repoKey = $('#rpmlint_repo_select_' + index + ' option:selected').attr('value');
  ajaxDataShow.repository = $('#rpmlint_repo_select_' + index + ' option:selected').html();
  ajaxDataShow.architecture = $('select[name="rpmlint_arch_select_' + index + '_' + repoKey + '"] option:selected').attr('value');
  $.ajax({
    url: '/package/rpmlint_log',
    data: ajaxDataShow,
    success: function (data) {
      $('#rpmlint_display_' + index).html(data);
    }
  });
}

// TODO: Stop using toggleBuildInfo in favor of the generic toggleCollapsibleTooltip
function toggleBuildInfo() { // jshint ignore:line
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
