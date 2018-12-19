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

  $('#linked_project').on('autocompletechange', function() {
    var projectName = $(this).val(),
        source = $('#linked_package').autocomplete('option', 'source');

    if (!projectName) return;

    // Ensure old parameters got removed
    source = source.replace(/\?.+/, '') + '?project=' + projectName;
    // Update the source target of the package autocomplete
    $('#linked_package').autocomplete('option', { source: source });
  });
});
