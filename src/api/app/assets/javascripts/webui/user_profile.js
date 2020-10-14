function moveInvolvementToContainer() { // jshint ignore:line
  var container = $('#involvement-and-activity');
  if ($('#involvement-and-activity > .tab-content:visible').length > 0)
    container = $('.tab-pane#involved-projects-and-packages');

  container.prepend($('#involvement'));
}
