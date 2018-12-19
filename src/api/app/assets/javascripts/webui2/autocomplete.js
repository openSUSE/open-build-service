$(document).ready(function() {
  $('.obs-autocomplete').each(function() {
    $(this).autocomplete({
      // Note: 'append' is optional and only needed when there is no element with class ui-front
      appendTo:  $(this).data('append'),
      source:    $(this).data('source'),
      minLength: 2,
      search: function() {
        $(this).prev().find('i').toggleClass('fa-search fa-spinner fa-spin');
      },
      response: function() {
        $(this).prev().find('i').toggleClass('fa-search fa-spinner fa-spin');
      }
    });
  });
});

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

function suggestRepositoryName(id, projectName, repositoryName){
  $(id + ' #repo_name').val(projectName.replace(/:/g, '_') + '_' + repositoryName);
}

function autocompleteRepositories(id, projectName) {
  var repositoriesId = (id + ' #target_repo');

  $(repositoriesId).html('');
  $(id + ' #repo_name').val('');
  $(repositoriesId).prop('disabled', true);

  if (projectName === '') return;

  $.ajax({
    url: $(repositoriesId).data('ajaxurl'),
    data: { project: projectName },
    success: function (data) {
      if(data.length === 0) {
        $(repositoriesId).append(new Option('No repositories found'));
      } else {
      $.each(data, function (idx, val) {
        $(repositoriesId).append(new Option(val));
      });

      suggestRepositoryName(id, projectName, data[0]);

      $(repositoriesId).prop('disabled', false);
      }
    }
  });
}

function repositoriesSetupAutocomplete(id) { // jshint ignore:line
  var inputId = (id + ' #target_project');
  var icon = $(id + ' .project-search-icon i:first-child');

  $(inputId).autocomplete({
    appendTo: (id + ' .modal-body'),
    source: $(inputId).data('ajaxurl'),
    minLength: 2,
    select: function(event, ui) {
      autocompleteRepositories(id, ui.item.value);
    },
    change: function() {
      autocompleteRepositories(id, $(inputId).val());
    },
    search: function() {
      icon.addClass('d-none');
      icon.next().removeClass('d-none');
    },
    response: function() {
      icon.removeClass('d-none');
      icon.next().addClass('d-none');
    }
  });

  $(id + ' #target_repo').change(function () {
    suggestRepositoryName(id, $(inputId).val(), $(this).val());
  });
}
