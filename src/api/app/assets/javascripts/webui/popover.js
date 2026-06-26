$(function () {
  initializePopovers('[data-bs-toggle="popover"]');
});

function initializePopovers(cssSelector, params) {
  var defaultParams = { trigger: 'hover click' };
  var newParams = $.extend(defaultParams, params);

  // Remove all popovers as they might be stagnant due to a partial page reload
  $('div.popover').remove();

  var popoverTriggerList = [].slice.call(document.querySelectorAll(cssSelector));
  popoverTriggerList.map(function (popoverTriggerEl) {
    return new bootstrap.Popover(popoverTriggerEl, newParams);
  });
}
