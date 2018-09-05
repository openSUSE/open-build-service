function autocompleteDevelProject(sourcePath) { // jshint ignore:line
  $("#devel_project").autocomplete({
    appendTo: '.modal-body',
    source: sourcePath,
    search: function(event, ui) { // jshint ignore:line
      $(this).addClass('loading-spinner');
    },
    response: function(event, ui) { // jshint ignore:line
      $(this).removeClass('loading-spinner');
    },
    minLength: 2});
}
