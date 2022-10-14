function moveInvolvementToContainer() { // jshint ignore:line
  var container = $('#involvement-and-activity');
  if ($('#involvement-and-activity > .tab-content:visible').length > 0)
    container = $('.tab-pane#involved-projects-and-packages');

  container.prepend($('#involvement'));
  $('#involvement').removeClass('d-none');
}

function updateCharactersCount(e) { // jshint ignore:line
  var maxLength = $(e.target).attr('maxlength');
  var currentLength = $(e.target).val().length;
  var remainingCount = maxLength - currentLength;

  // Change font color to "danger" when low amount of characters left
  $('#bio-chars-counter').toggleClass('text-danger', remainingCount < 10);

  // Make text singular or plural based on the amount of characters
  var plural = (remainingCount === 1) ? '' : 's';
  $('#bio-chars-counter').css("visibility", "visible").text(remainingCount + " character" + plural + " remaining");
}
