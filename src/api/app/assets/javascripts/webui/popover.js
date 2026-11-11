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

// Popovers listing request actions stay open while hovered, so long lists can be scrolled.
// Delegated events, so they also work after partial reloads of the requests list.
$(document).on('mouseenter click', '[data-request-actions-popover]', function () {
  window.clearTimeout(this.hidePopoverTimeout);
  var tip = document.getElementById(this.getAttribute('aria-describedby'));
  if (!tip || !tip.classList.contains('show')) {
    bootstrap.Popover.getOrCreateInstance(this, { trigger: 'manual' }).show();
  }
});

$(document).on('mouseleave', '[data-request-actions-popover]', function () {
  hideRequestActionsPopoverSoon(this);
});

$(document).on('mouseenter', '.request-actions-popover', function () {
  var trigger = document.querySelector('[aria-describedby="' + this.id + '"]');
  if (trigger) window.clearTimeout(trigger.hidePopoverTimeout);
});

$(document).on('mouseleave', '.request-actions-popover', function () {
  var trigger = document.querySelector('[aria-describedby="' + this.id + '"]');
  if (trigger) hideRequestActionsPopoverSoon(trigger);
});

// Leaves time to move the pointer from the trigger to the popover
function hideRequestActionsPopoverSoon(trigger) {
  window.clearTimeout(trigger.hidePopoverTimeout);
  trigger.hidePopoverTimeout = window.setTimeout(function () {
    bootstrap.Popover.getOrCreateInstance(trigger).hide();
  }, 300);
}
