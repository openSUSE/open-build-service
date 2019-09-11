$(function () {
  initializePopovers('[data-toggle="popover"]');
});

function initializePopovers(cssSelector, params) {
  var defaultParams = { trigger: 'hover click' };
  var newParams = $.extend(defaultParams, params);

  // Remove all popovers as they might be stagnant due to a partial page reload
  $('div.popover').remove();

  $(cssSelector).popover(newParams).on('show.bs.popover', function() {
    // Hide all popovers, so only the one triggering this event will be shown
    $(cssSelector).popover('hide');
  });
}
