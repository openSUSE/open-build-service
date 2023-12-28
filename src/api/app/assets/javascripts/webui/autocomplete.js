$(document).ready(function() {
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
