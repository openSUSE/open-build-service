// Purpose: fix the search bar look&feel in the data tables to look like the rest of the search bars in the app.
$(document).ready(function() {
  window.setTimeout(function() {
    $('.dataTables_filter').each(function() {
      const filterWrapper = $(this);
      filterWrapper.addClass('form-group d-flex justify-content-end mb-1');

      const inputWrapper = $(this).children('label');
      inputWrapper.addClass('input-group flex-nowrap');
      inputWrapper.css('max-width', '500px');
      inputWrapper.append("<span class='input-group-text'><i class='fa fa-search'></i></span>");
    }); }, 50);
});
