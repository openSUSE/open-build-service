function autocompleteStagingManager() {
  $('#staging_manager').autocomplete({
    appendTo: '#add-staging-manager-modal-input',
    source: $('#add-staging-manager-modal-input').data('autocomplete-url'),
    search: function(event, ui) {
      var icon = $('#add-staging-manager-search-icon i:first-child');
      icon.addClass('d-none');
      icon.next().removeClass('d-none');
    },
    response: function(event, ui) {
      var icon = $('#add-staging-manager-search-icon i:first-child');
      icon.removeClass('d-none');
      icon.next().addClass('d-none');
    },
    minLength: 2
  });
}
