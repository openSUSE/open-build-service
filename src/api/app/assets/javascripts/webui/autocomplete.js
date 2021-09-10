function setupAutocomplete() {
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
}

$(document).ready(function() {

  setupAutocomplete();

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

  $('#linked_project, #review_project, #project_name, #project').on('autocompletechange', function() {
    var projectName = $(this).val(),
        packageInput = $('#linked_package, #review_package, #package_name, #package');

    if (!packageInput.is(':visible')) return;

    if (!projectName) {
      packageInput.val('').attr('disabled', true);
      return;
    }

    if (packageInput.attr('disabled')) { packageInput.removeAttr('disabled').focus(); }

    var source = packageInput.autocomplete('option', 'source');

    // Ensure old parameters got removed
    source = source.replace(/\?.+/, '') + '?project=' + projectName;
    // Update the source target of the package autocomplete
    packageInput.autocomplete('option', { source: source });
  });
});
