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

/* bootstrap's tabs javascript doesn't remove the active class
   when tabs are implemented without the usage of ul and li */
function toggleTabs(tabLinkContainerId) { // jshint ignore:line
  $('#'+tabLinkContainerId+' a').on('click', function(e) {
    e.preventDefault();
    $(this).tab('show');
    var currentTabLink = $(this);
    $('#'+tabLinkContainerId+' a').removeClass('active');
    currentTabLink.addClass('active');
  });
}

$.fn.hasOverflow = function() {
  var element = $(this)[0];
  // We must check that the scroll is bigger than the offset to shrink the tabs until needed (the 1 pixel difference is caused by a Firefox issue)
  return (element.offsetHeight < element.scrollHeight - 1) || (element.offsetWidth < element.scrollWidth - 1);
};

$.fn.collapseCollapsible = function(){
  var collapsibleElements = this;
  
  return collapsibleElements.each(function() {
    var element = $(this);
    refreshTabs(element);

    $(window).resize(function() { refreshTabs(element); });
  });
};

$(document).ready(function() {
  $('ul.collapsible').collapseCollapsible();
});
