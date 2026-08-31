/* exported setupAutocomplete */

function setupAutocomplete(selector) {
  $(selector).autocomplete({
    // Note: 'append' is optional and only needed when there is no element with class ui-front
    appendTo:  $(selector).data('append'),
    source:    $(selector).data('source'),
    minLength: 2,
    search: function() {
      $(selector).next().find('i').toggleClass('fa-search fa-spinner fa-spin');
    },
    response: function() {
      $(selector).next().find('i').toggleClass('fa-search fa-spinner fa-spin');
    }
 });
}

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

  $('#linked_project, #review_project, #project_name, #canned_response_project, #project').on('autocompletechange', function() {
    var projectName = $(this).val(),
        packageInput = $('#linked_package, #review_package, #package_name, #canned_response_package, #package');

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

  $('.architecture-autocomplete').on('click', '.add-button', function(event) {
    var parent          = $(this).closest('.architecture-autocomplete'),
        projectName     = parent.find('.ui-autocomplete-input').val(),
        dropdown        = parent.find('.repository-dropdown'),
        repositoryName = dropdown.find(":selected").val(),
        button          = event.target,
        list            = parent.find('.item-list'),
        itemTemplate    = document.querySelector('#item-list-template'),
        checkboxTemplate= document.querySelector('#item-list-checkbox');

    if (projectName === '') return;
    if (repositoryName === '') return;

    $.ajax({
      url: button.dataset.source,
      data: { project: projectName, repository: repositoryName },
      success: function (data) {
        if(data.length !== 0) {
          if ("content" in document.createElement("template")) {
            const item = document.importNode(itemTemplate.content, true);
            let itemName = item.querySelector('.item-name');
            itemName.innerText = projectName + '/' + repositoryName;
            let checkboxList = item.querySelector('.item-checkboxes');
            Object.entries(data).forEach(([id, name]) => {
              const checkbox = document.importNode(checkboxTemplate.content, true);
              let checkboxLabel = checkbox.querySelector('label');
              checkboxLabel.setAttribute('for', checkboxLabel.getAttribute('for') + id);
              checkboxLabel.innerText = name;
              let checkboxInput = checkbox.querySelector('input');
              checkboxInput.id = checkboxInput.id + id;
              checkboxInput.value = id;
              checkboxList.appendChild(checkbox);
            });
            list.append(item);
          }
        }
      }
    });
  });
});
