function setSpinnersForDeletion() { // jshint ignore:line
  $("#staging-workflow-delete").on('ajax:beforeSend', function(){
    $(this).find('.delete-spinner').removeClass('d-none');
  });

  $("#staging-workflow-delete").on('ajax:complete', function(){
    $(this).find('.delete-spinner').addClass('d-none');
  });
}
