$.fn.hasOverflow = function() {
  var element = $(this)[0];

  if ((element.offsetHeight < element.scrollHeight) || (element.offsetWidth < element.scrollWidth)) {
    return true;
  }

  return false;
};

$.fn.collapse = function(){
  var collapsibleElement = this,
      container = this.parent(),
      item;

  return collapsibleElement.each(function() {
    function resize(trigger, selector, target) {
      while(container.hasOverflow() === trigger && (item = collapsibleElement.find(selector)).length) {
        item.toggleClass('nav-link dropdown-item');
        if (trigger) { item.parent().empty(); }
        item.prependTo(target);
      }
    }

    function refresh() {
      if (container.hasOverflow()) {
        // Shrink... moving links to the dropdown
        resize(true, 'li:not(.dropdown):not(:empty):last a', 'li.dropdown .dropdown-menu');
      }
      else {
        // Grow... moving links to tabs
        resize(false, 'li.dropdown .dropdown-menu a:first', 'li:not(.dropdown):empty:first');

        // TODO: Grow is triggered when it shouldn't sometimes (this fixes it...)
        resize(true, 'li:not(.dropdown):not(:empty):last a', 'li.dropdown .dropdown-menu');
      }

      var dropdownState = collapsibleElement.find('.dropdown-menu').is(':not(:empty)');
      collapsibleElement.find('li.dropdown').toggle(dropdownState);
    }
    refresh();

    $(window).resize(function() { refresh(); });
  });
};

$(document).ready(function() {
  $('ul.collapsible').collapse();
});
