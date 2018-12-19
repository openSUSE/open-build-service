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

  $('.repository-autocomplete').on('autocompleteselect autocompletechange', function(event, ui) {
    var projectName,
        dropdown        = $(this).find('.repository-dropdown'),
        repoNameElement = $(this).find('.repository-name');

    // Get project name
    if (event.type === 'autocompleteselect') {
      projectName = ui.item.value;
    } else {
      projectName = $(this).find('.ui-autocomplete-input').val();
    }

    // Clear form
    dropdown.html('').prop('disabled', true);
    repoNameElement.val('');

    if (projectName === '') return;

    // Update dropdown
    $.ajax({
      url: dropdown.data('source'),
      data: { project: projectName },
      success: function (data) {
        if(data.length === 0) {
          dropdown.append(new Option('No repositories found'));
        } else {
          $.each(data, function (_, val) {
            dropdown.append(new Option(val));
          });

          repoNameElement.val(projectName.replace(/:/g, '_') + '_' + data[0]);

          dropdown.prop('disabled', false);
        }
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
