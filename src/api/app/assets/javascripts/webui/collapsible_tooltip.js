$(document).on('click', '.collapsible-tooltip', function(){
  var replaceTitle = $(this).attr('title') === 'Click to keep it open' ? 'Click to close it' : 'Click to keep it open';
  var infoContainer = $(this).parents('.collapsible-tooltip-parent').next();
  $(infoContainer).toggleClass('collapsed');
  $(infoContainer).removeClass('hover');
  $(this).attr('title', replaceTitle);
});

$(document).on('mouseover', '.collapsible-tooltip', function(){
  $(this).parents('.collapsible-tooltip-parent').next().addClass('hover');
});

$(document).on('mouseout', '.collapsible-tooltip', function(){
  $(this).parents('.collapsible-tooltip-parent').next().removeClass('hover');
});
