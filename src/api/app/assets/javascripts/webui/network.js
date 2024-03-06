$(document).on( "ajaxError", function(event, xhdr, settings, thrownError) {
  $('#flash').show().append(generateFlashError(`An issue occurred while loading '${settings.url}': '${thrownError}'. Please try again or reload the page.`)); // jshint ignore:line
});
