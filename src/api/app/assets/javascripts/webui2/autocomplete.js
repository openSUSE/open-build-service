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

function autocompleteBranchProjectName(linkedProjectSource) { // jshint ignore:line
  $('#linked_project').autocomplete({
    appendTo: '#original-project-name',
    source: linkedProjectSource,
    search: function(event, ui) { // jshint ignore:line
      autocompleteSpinner('search-icon-project', true);
    },
    response: function(event, ui) { // jshint ignore:line
      autocompleteSpinner('search-icon-project', false);
    },
    minLength: 2
  });
}

function autocomleteBranchPackageName(linkedPackageSource) { // jshint ignore:line
  $('#linked_package').autocomplete({
    appendTo: '#original-package-name',
    source: function(request, response) {
      $.ajax({
        url: linkedPackageSource,
        data: {
          project: $('#linked_project').val(),
          term: request.term,
        },
        success: function(data) {
          response($.map(data, function(item) { return { label: item, value: item }; }));
        },
      });
    },
    search: function(event, ui) { // jshint ignore:line
      autocompleteSpinner('search-icon-package', true);
    },
    response: function(event, ui) { // jshint ignore:line
      autocompleteSpinner('search-icon-package', false);
    },
    minLength: 2
  });
}

function autocompleteSpinner(spinnerId, searching) {
  var icon = $('#' + spinnerId + ' i:first-child');
  if (searching) {
    icon.addClass('d-none');
    icon.next().removeClass('d-none');
  } else {
    icon.removeClass('d-none');
    icon.next().addClass('d-none');
  }
}
