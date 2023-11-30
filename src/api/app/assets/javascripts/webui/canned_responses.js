function setupCannedResponses() { // jshint ignore:line
  $('[data-canned-controller]').on('click', '[data-canned-response]', function(e) {
    $(e.target).closest('[data-canned-controller]').find('textarea').val(e.target.dataset.cannedResponse);
  });
}
