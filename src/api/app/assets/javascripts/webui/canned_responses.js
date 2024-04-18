function setupCannedResponses() { // jshint ignore:line
  $('[data-canned-controller]').on('click', '[data-canned-response]', function(e) {
    $(e.target).closest('[data-canned-controller]').find('textarea').val(e.target.dataset.cannedResponse);
    // TODO: adapt the following line when Decision#kind is replaced with Decision#type
    // Set `cleared` by default for canned responses with decision_kind nil
    let kind = e.target.dataset.decisionKind === 'favored' ? 'favor' : 'cleared';
    $(e.target).closest('[data-canned-controller]').find('#decision_kind').val(kind);
    // we have to enable the submit button for the comments form
    $(e.target).closest('[class*="-comment-form"]').find('input[type="submit"]').prop('disabled', false);
  });
}
