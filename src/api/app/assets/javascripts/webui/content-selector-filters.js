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
$(document).on('change keyup', '#content-selector-filters-form input, #content-selector-filters-form select', function() {
  highlightSelectedFilters();
  window.clearTimeout(submitFiltersTimeout);
  submitFiltersTimeout = window.setTimeout(submitFilters, 2000);
});

$(document).ready(function(){
  highlightSelectedFilters();
});
