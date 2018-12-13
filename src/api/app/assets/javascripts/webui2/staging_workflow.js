function setSpinnersForDeletion() { // jshint ignore:line
  $("#staging-workflow-delete").on('ajax:beforeSend', function(){
    $(this).find('.delete-spinner').removeClass('d-none');
  });

  $("#staging-workflow-delete").on('ajax:complete', function(){
    $(this).find('.delete-spinner').addClass('d-none');
  });
}

function autocompleteStagingManagersGroup() { // jshint ignore:line
  $('#managers_title').autocomplete({
    appendTo: '#assign-managers-group-modal-input',
    source: $('#managers_title').data('autocompleteGroupsUrl'),
    search: function() {
      var icon = $('#assign-managers-group-search-icon i:first-child');
      icon.addClass('d-none');
      icon.next().removeClass('d-none');
    },
    response: function() {
      var icon = $('#assign-managers-group-search-icon i:first-child');
      icon.removeClass('d-none');
      icon.next().addClass('d-none');
    },
    minLength: 2
  });
}
