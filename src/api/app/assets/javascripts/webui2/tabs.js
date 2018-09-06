function resizeTabs(trigger, tabListContainer, selector, target) {
  var item;
  while(tabListContainer.hasOverflow() === trigger && (item = tabListContainer.find(selector)).length) {
    item.toggleClass('nav-link dropdown-item');
    if (trigger) { item.parent().empty(); }
    item.prependTo(tabListContainer.find(target));
  }
}

function refreshTabs(tabList) {
  var tabListContainer = $(tabList.parent());
  if (tabListContainer.hasOverflow()) {
    // Shrink... moving links to the dropdown
    resizeTabs(true, tabListContainer, 'li:not(.dropdown):not(:empty):last a', 'li.dropdown .dropdown-menu');
  }
  else {
    // Grow... moving links to tabs
    resizeTabs(false, tabListContainer, 'li.dropdown .dropdown-menu a:first', 'li:not(.dropdown):empty:first');

    // TODO: Grow is triggered when it shouldn't sometimes (this fixes it...)
    resizeTabs(true, tabListContainer, 'li:not(.dropdown):not(:empty):last a', 'li.dropdown .dropdown-menu');
  }

  var dropdownState = tabList.find('.dropdown-menu').is(':not(:empty)');
  tabList.find('li.dropdown').toggle(dropdownState);
}

$.fn.hasOverflow = function() {
  var element = $(this)[0];
  return (element.offsetHeight < element.scrollHeight) || (element.offsetWidth < element.scrollWidth);
};

$.fn.collapse = function(){
  var collapsibleElements = this;
  
  return collapsibleElements.each(function() {
    var element = $(this);
    refreshTabs(element);

    $(window).resize(function() { refreshTabs(element); });
  });
};

$(document).ready(function() {
  $('ul.collapsible').collapse();
});
