function toggleCollapsibleTooltip() { // jshint ignore:line
  $('.collapsible-tooltip').on('click', function(){
    var replaceTitle = $(this).attr('title') === 'Click to keep it open' ? 'Click to close it' : 'Click to keep it open';
    var infoContainer = $(this).parents('.collapsible-tooltip-parent').next();
    $(infoContainer).toggleClass('collapsed');
    $(infoContainer).removeClass('hover');
    $(this).attr('title', replaceTitle);
  });
  $('.collapsible-tooltip').on('mouseover', function(){
    $(this).parents('.collapsible-tooltip-parent').next().addClass('hover');
  });
  $('.collapsible-tooltip').on('mouseout', function(){
    $(this).parents('.collapsible-tooltip-parent').next().removeClass('hover');
  });
}
