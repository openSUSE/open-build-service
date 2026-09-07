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
          // Without a placeholder the first repository is preselected, so picking it fires no change event
          var placeholder = dropdown.data('placeholder');
          if (placeholder) { dropdown.append(new Option(placeholder, '', true, true)); }

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

  $('.architecture-autocomplete').on('change', '.repository-dropdown', function() {
    var parent              = $(this).closest('.architecture-autocomplete'),
        projectName         = parent.find('.ui-autocomplete-input').val(),
        repositoryName      = $(this).val(),
        list                = parent.find('.item-list'),
        warning             = parent.find('.architecture-warning'),
        existingRepositories= parent.data('existing-repositories') || [],
        itemTemplate        = document.querySelector('#item-list-template'),
        checkboxTemplate    = document.querySelector('#item-list-checkbox');

    if (projectName === '') return;
    if (repositoryName === '') return;
    if (!("content" in document.createElement("template"))) return;

    var repository = projectName + '/' + repositoryName;

    // Adding the same repository twice would duplicate the architecture checkboxes
    if (list.find('[data-repository="' + repository + '"]').length !== 0) return;

    $.ajax({
      url: parent.data('architectures-source'),
      data: { project: projectName, repository: repositoryName },
      success: function (data) {
        if (Object.keys(data).length === 0) {
          warning.text('The repository ' + repository + ' has no architectures.').removeClass('d-none');
          return;
        }

        const item = document.importNode(itemTemplate.content, true);
        item.querySelector('li').dataset.repository = repository;
        if (existingRepositories.indexOf(repository) === -1) {
          item.querySelector('li').classList.add('list-group-item-success');
        }
        let itemName = item.querySelector('.item-name');
        itemName.innerText = repository;
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

        warning.addClass('d-none');
        parent.find('.collapse').collapse('hide');
      }
    });
  });

  $('.architecture-autocomplete').on('click', '.remove-repository', function(event) {
    event.preventDefault();
    $(this).closest('li').remove();
  });

  // A repository without any architecture selected is silently dropped on save, so warn instead of submitting
  $('.architecture-autocomplete').closest('form').on('submit', function(event) {
    var warning = $(this).find('.architecture-warning'),
        invalid = false;

    $(this).find('.item-list > li').each(function() {
      var valid = $(this).find('input.form-check-input:checked').length !== 0;

      $(this).toggleClass('text-danger', !valid);
      if (!valid) invalid = true;
    });

    if (!invalid) {
      warning.addClass('d-none');
      return;
    }

    // Stop jquery_ujs from seeing this submit at all, otherwise it still disables the submit
    // button (via a delegated document handler scheduled with setTimeout) even though we
    // cancel the actual submission, leaving the button stuck disabled.
    event.preventDefault();
    event.stopPropagation();
    warning.text('Please select at least one architecture for every repository.').removeClass('d-none');
  });
});
