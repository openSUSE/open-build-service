function toggleTooltip() { // jshint ignore:line
  $('.toggle-tooltip').on('click', function(){
    var replaceTitle = $(this).attr('title') === 'Click to keep it open' ? 'Click to close it' : 'Click to keep it open';
    var infoContainer = $(this).parents('.toggle-tooltip-parent').next();
    $(infoContainer).toggleClass('collapsed');
    $(infoContainer).removeClass('hover');
    $(this).attr('title', replaceTitle);
  });
  $('.toggle-tooltip').on('mouseover', function(){
    $(this).parents('.toggle-tooltip-parent').next().addClass('hover');
  });
  $('.toggle-tooltip').on('mouseout', function(){
    $(this).parents('.toggle-tooltip-parent').next().removeClass('hover');
  });
}
