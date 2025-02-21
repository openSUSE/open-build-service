function highlightSelectedFilters() {
  var filters = $('#content-selector-filters .accordion .accordion-item');
  filters.each(function() {
    var currentFilter = $(this);
    var selectedContentWrapper = currentFilter.find('.selected-content');
    if (selectedContentWrapper.length > 0) {
      var anySelected = [];
      $(this).find('input').each(function() {
        if ($(this).is(':checked')) {
          anySelected.push($(this).next('label').html());
        }
      });
      if (anySelected.length > 0) {
        currentFilter.find('.selected-content').html(anySelected.join(', '));
      }
      else {
        currentFilter.find('.selected-content').text("");
      }
    }
  });
}
function submitFilters() {
  $('#content-selector-filters-form').submit();
  $('#content-selector-filters input').attr('disabled', 'disabled');
  $('.content-list').hide();
  $('.content-list-loading').removeClass('d-none');
}

let submitFiltersTimeout;
const autoSubmitOnChangeSelector = '#content-selector-filters-form .auto-submit-on-change';
$(document).on('change keyup', `${autoSubmitOnChangeSelector} input, ${autoSubmitOnChangeSelector} select`, function() {
  // Clear the timeout to prevent the pending submission, if any
  window.clearTimeout(submitFiltersTimeout);

  // Validate datetime-local inputs
  if ($(this).attr('type') === 'datetime-local') {
    // Parse the value
    const datetime = new Date($(this).val());
    if (isNaN(datetime.getTime())) {
      window.console.error("Invalid date or time format");
      return;
    }
  }
  highlightSelectedFilters();

  // Set a timeout to submit the filters
  submitFiltersTimeout = window.setTimeout(submitFilters, 2000);
});

// NOTE: no need to implement a keypress ENTER event, pressing enter on a form input will submit the form by default
// Implement a click event on the search icon below
const autoSubmitOnClickSelector = '#content-selector-filters-form .fa-search';
$(document).on('click', autoSubmitOnClickSelector, function() {
  // Clear the timeout to prevent the pending submission, if any
  window.clearTimeout(submitFiltersTimeout);

  submitFilters();
});

$(document).ready(function(){
  highlightSelectedFilters();
  $(autoSubmitOnClickSelector).each(function() {$(this).parent('.input-group-text').css('cursor', 'pointer');});
});
