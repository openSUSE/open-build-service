$(function () {
  initializePopovers('[data-bs-toggle="popover"]');

  // Close pinned popovers when clicking outside
  document.addEventListener('click', function (e) {
    var pinnedPopovers = document.querySelectorAll('[data-popover-pinned="true"]');
    pinnedPopovers.forEach(function (el) {
      // Check if click is outside the trigger and outside the popover
      var popover = bootstrap.Popover.getInstance(el);
      if (popover && !el.contains(e.target) && !document.querySelector('.popover:hover')) {
        el.dataset.popoverPinned = 'false';
        popover.hide();
      }
    });
  });
});

function initializePopovers(cssSelector, params) {
  var defaultParams = { trigger: 'hover', html: true };
  var newParams = $.extend(defaultParams, params);

  // Remove all popovers as they might be stagnant due to a partial page reload
  $('div.popover').remove();

  var popoverTriggerList = [].slice.call(document.querySelectorAll(cssSelector));
  popoverTriggerList.map(function (popoverTriggerEl) {
    var popover = new bootstrap.Popover(popoverTriggerEl, newParams);

    // When clicked, pin the popover open so users can interact with content
    popoverTriggerEl.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      var isPinned = popoverTriggerEl.dataset.popoverPinned === 'true';

      if (isPinned) {
        // Unpin and hide
        popoverTriggerEl.dataset.popoverPinned = 'false';
        popover.hide();
      } else {
        // Pin the popover - it will stay open until clicked again
        popoverTriggerEl.dataset.popoverPinned = 'true';
        popover.show();
      }
    });

    // Don't hide on mouseout if pinned
    popoverTriggerEl.addEventListener('mouseleave', function () {
      if (popoverTriggerEl.dataset.popoverPinned === 'true') {
        popover.show();
      }
    });

    return popover;
  });
}
