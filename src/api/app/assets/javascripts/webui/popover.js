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
