function setupCannedResponses() { // jshint ignore:line
  $('[data-canned-controller]').on('click', '[data-canned-response]', function(e) {
    $(e.target).closest('[data-canned-controller]').find('textarea').val(e.target.dataset.cannedResponse);
    // let's make sure this exists first, to avoid errors
    if ($(e.target).closest('[data-canned-controller]').find('#decision_type').length !== 0) {
      // we gather up all the possible options, to make sure whatever we click doesn't wipe out the selection box
      var optionsHtml = $(e.target).closest('[data-canned-controller]').find('#decision_type')[0].options;
      var options = Array.from(optionsHtml).map(el => el.value);
      // and if whatever we are trying to set exists within the options, we set it, otherwise we don't change the select box
      if (options.includes(e.target.dataset.decisionType))
        $(e.target).closest('[data-canned-controller]').find('#decision_type').val(e.target.dataset.decisionType);
    }
    // we have to enable the submit button for the comments form
    $(e.target).closest('[class*="-comment-form"]').find('input[type="submit"]').prop('disabled', false);
  });
}
