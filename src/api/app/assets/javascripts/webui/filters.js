$(document).ready(function(){
  function highlightSelectedFilters() {
    var filters = $('#filters .accordion .accordion-item');
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
  highlightSelectedFilters();

  function submitFilters() {
    $('#filter-form').submit();
    $('#filters input').attr('disabled', 'disabled');
    $('#requests-list').hide();
    $('#requests-list-loading').removeClass('d-none');
  }
  let submitFiltersTimeout;

  $(document).on('change keyup', '#filter-form input, #filter-form select', function() {
    highlightSelectedFilters();
    window.clearTimeout(submitFiltersTimeout);
    submitFiltersTimeout = window.setTimeout(submitFilters, 2000);
  });
});
