var canSave = false;

function hideOverlay(dialog) {
  $('.overlay').hide();
  dialog.addClass('hidden');
}

function saveImage() {
  if (canSave) {
    $.ajax({ url: "#{url_for(controller: 'kiwi/images', action: :show, id: @image)}",
      dataType: 'json',
      success: function(json) {
        var is_outdated = json.is_outdated;
        if (is_outdated && !confirm("This image has been modified while you were editing it.\nDo you want to apply the changes anyway?"))
          return;
        $('#kiwi-image-update-form').submit();
      }
    });
  }
}

function enableSave(){
  canSave = true;
  $('#kiwi-image-update-form-save, #kiwi-image-update-form-revert').addClass('enabled');
}

function editDescriptionDialog(){
  var dialog = $('#kiwi-description').find('.dialog');
  dialog.removeClass('hidden');
  $('.overlay').show();
}

function editPreferencesDialog(){
  var dialog = $('#kiwi-preferences').find('.dialog');
  dialog.removeClass('hidden');
  $('.overlay').show();
}

function editPackageDialog(){
  var fields = $(this).parents('.nested-fields');
  var dialog = fields.find('.dialog');
  dialog.removeClass('hidden');
  $('.overlay').show();
}

function editRepositoryDialog(){
  var fields = $(this).parents('.nested-fields');
  var dialog = fields.find('.dialog');
  var normal_mode = fields.find('.normal-mode');
  var expert_mode = fields.find('.expert-mode');
  var source_path = fields.find("[id$='source_path']");

  dialog.removeClass('hidden');
  var matched_obs_source_path = source_path.val().match(/^obs:\/\/([^\/]+)\/([^\/]+)$/);
  if (matched_obs_source_path) {
    var project_field = fields.find('[name=target_project]');
    var repo_field = fields.find('[name=target_repo]');
    var alias_field = fields.find('[name=alias_for_repo]');
    var expert_repo_alias = fields.find("[id$='alias']");
    var repo_type_field = fields.find("[id$='repo_type']");
    alias_field.val(expert_repo_alias.val());
    project_field.val(matched_obs_source_path[1]);
    repo_field.html('');
    repo_field.append(new Option(matched_obs_source_path[2]));
    repo_field.val(matched_obs_source_path[2]);
    repo_type_field.val('rpm-md');

    normal_mode.show();
    expert_mode.hide();
  }
  else {
    normal_mode.hide();
    expert_mode.show();
  }
  updateModeButton(fields);

  $('span[role=status]').text(''); // empty autocomplete status

  $('.overlay').show();
}

function addRepositoryErrorMessage(source_path, field) {
  if (source_path == 'obsrepositories:/') {
    field.text('If you want use obsrepositories:/ as source_path, please check the checkbox "use project repositories".');
  }
  else {
    field.text('The source path can not be empty!');
  }

  field.removeClass('hidden');
}

function closeDescriptionDialog() {
  var fields = $(this).parents('.nested-fields');
  var dialog = fields.find('.dialog');
  var name = dialog.find("[id$='name']");

  if (name.val() !== '') {
    $('#image-name').text(name.val());
  }
  else {
    fields.find(".ui-state-error").removeClass('hidden');
    return false;
  }

  var elements = fields.find('.fill');
  for(var i=0; i < elements.length; i++) {
    var object = dialog.find("[id$='" + $(elements[i]).data('tag') + "']");
    if ( object.val() != "") {
      $(elements[i]).text(object.val());
    }
  }

  addDefault(dialog);

  if (!canSave) {
    enableSave();
  }

  fields.find(".ui-state-error").addClass('hidden');

  hideOverlay(dialog);
}


function closePreferencesDialog() {
  var fields = $(this).parents('.nested-fields');
  var dialog = fields.find('.dialog');

  var elements = fields.find('.fill');
  for(var i=0; i < elements.length; i++) {
    var object = dialog.find("[id$='" + $(elements[i]).data('tag') + "']");
    if ( object.val() != "") {
      if ( $(elements[i]).data('tag') == 'image_type' ) {
        $(elements[i]).text(object.find(":selected").text());
      }
      else {
        $(elements[i]).text(object.val());
      }
    }
  }

  addDefault(dialog);

  if (!canSave) {
    enableSave();
  }

  hideOverlay(dialog);
}



function closeDialog() {
  var fields = $(this).parents('.nested-fields');
  var is_repository = fields.parents('#kiwi-repositories-list').size() == 1;
  var name = fields.find('.kiwi_element_name');
  var dialog = fields.find('.dialog');

  if(is_repository) {
    var source_path = dialog.find("[id$='source_path']");
    if(source_path.val() !== '' && source_path.val() !== 'obsrepositories:/') {
      var alias = dialog.find("[id$='alias']");
      if (alias.val() !== '') {
        name.text(alias.val());
      }
      else {
        name.text(source_path.val().replace(/\//g, '_'));
      }
    }
    else {
      addRepositoryErrorMessage(source_path.val(), fields.find(".ui-state-error"));
      return false;
    }
  }
  else {
    var namePackage = dialog.find("[id$='name']").val();
    if(namePackage !== '') {
      name.text(namePackage);

      arch = dialog.find("[id$='arch']").val();
      if(arch != '') {
        name.append(" <small>(" + arch + ")</small>");
      }
    }
    else {
      fields.find(".ui-state-error").removeClass('hidden');
      return false;
    }
  }

  addDefault(dialog);

  if( /^Add/.test(dialog.find('.box-header').text())) {
    dialog.find('.box-header').text('Edit '+ dialog.find('.box-header').text().split(' ')[1]);
  }

  fields.find(".ui-state-error").addClass('hidden');
  fields.find('.kiwi_list_item').removeClass('has-error');
  dialog.removeClass('new_element');

  if (!canSave) {
    enableSave();
  }

  hideOverlay(dialog);
}

function revertDialog() {
  var fields = $(this).parents('.nested-fields');
  var dialog = fields.find('.dialog');
  dialog.find(".ui-state-error").addClass('hidden');

  if(dialog.hasClass('new_element')) {
    hideOverlay(dialog);

    fields.find('.remove_fields').click();
  }
  else {
    $.each(dialog.find('input, select'), function(index, input) {
      if (input.type === 'checkbox') {
        $(input).prop('checked', input.getAttribute('data-default') === 'true');
      }
      else {
        $(input).val(input.getAttribute('data-default'));
      }
    });

    hideOverlay(dialog);
  }
}

function addDefault(dialog) {
  $.each(dialog.find('input, select'), function(index, input) {
    if (input.type === 'checkbox') {
      input.setAttribute('data-default', input.checked);
    }
    else {
      input.setAttribute('data-default', $(input).val());
    }
  });
}

function repositoryModeToggle() {
  var fields = $(this).parents('.nested-fields');

  var normal_mode = fields.find('.normal-mode');
  var expert_mode = fields.find('.expert-mode');
  normal_mode.toggle();
  expert_mode.toggle();

  updateModeButton(fields);
}

function updateModeButton(fields) {
  var toggle_mode_button = fields.find('.kiwi-repository-mode-toggle');
  var expert_mode = fields.find('.expert-mode');
  toggle_mode_button.text(expert_mode.is(":visible") ? "Basic Mode" : "Expert Mode");
}

function hoverListItem() {
  $(this).find('.kiwi_actions').toggle();
}

function autocompleteKiwiRepositories(project, repo_field) {
  if (project === "")
      return;
  $('.ui-autocomplete-loading').show();
  repo_field.attr('disabled', 'true');
  $.ajax({
      url: repo_field.data('ajaxurl'),
      data: {project: project},
      success: function (data) {
        repo_field.html('');
        var foundoptions = false;
        $.each(data, function (idx, val) {
          repo_field.append(new Option(val));
          repo_field.removeAttr('disabled');
          foundoptions = true;
        });
        if (!foundoptions)
          repo_field.append(new Option('No repos found'));
      },
      complete: function (data) {
        $('.ui-autocomplete-loading').hide();
        repo_field.trigger("change");
      }
  });
}

function kiwiRepositoriesSetupAutocomplete(fields) {
  var project_field = fields.find('[name=target_project]');
  var repo_field = fields.find('[name=target_repo]');
  var alias_field = fields.find('[name=alias_for_repo]');

  project_field.autocomplete({
    source: project_field.data('ajaxurl'),
    minLength: 2,
    select: function (event, ui) {
      autocompleteKiwiRepositories(ui.item.value, repo_field);
    }
  });

  project_field.change(function () {
    autocompleteKiwiRepositories(project_field.val(), repo_field);
  });

  repo_field.change(function () {
    var repo_field_value = repo_field.val();
    if (repo_field.val() == 'No repos found') {
      repo_field_value = '';
    }
    var source_path = fields.find("[id$='source_path']");
    source_path.val("obs://" + project_field.val() + '/' + repo_field.val());
    alias_field.val(repo_field_value + '@' + project_field.val());
    alias_field.trigger("change");
    var repo_type_field = fields.find("[id$='repo_type']");
    repo_type_field.val('rpm-md');
  });

  alias_field.change(function () {
    var expert_repo_alias = fields.find("[id$='alias']");
    expert_repo_alias.val($(this).val());
  });
}

function kiwiPackagesSetupAutocomplete(fields) {
  var package_field = fields.find('[id$=name]');

  package_field.autocomplete({
    source: function (request, response) {
      var repositories = $("#kiwi-repositories-list [id$='source_path']").map(function() { return this.value;}).get();
      var repository_destroy_fields = $("#kiwi-repositories-list [id$='_destroy']");
      var using_project_repositories =  $('#kiwi_image_use_project_repositories').prop('checked');
      repository_destroy_fields.each(function(index, input){ // remove destroyed repositories from the payload
        if ($(input).val() == "1") {
          repositories.splice(index, 1);
        }
      });
      var payload = { term: request.term, repositories: repositories };
      if (using_project_repositories) {
        payload.use_project_repositories = true;
      }
      $.getJSON(package_field.data('ajaxurl'), payload,
        function (data) {
          response(data);
        });
    },
    minLength: 2
  });
}

$(document).ready(function(){
  // Save image
  $('#kiwi-image-update-form-save').click(saveImage);
  $('#kiwi_image_use_project_repositories').click(function(){
    $('#kiwi-repositories-list, #use-project-repositories-text').toggle();
    enableSave();
  });

  // Revert image
  $('#kiwi-image-update-form-revert').click(function(){
    if ($(this).hasClass('enabled')) {
      if (confirm('Attention! All unsaved data will be lost! Continue?')) {
        window.location = window.location.href;
        return false;
      }
    }
  });

  // Enable save button
  $('.remove_fields').click(enableSave);

  // Edit dialog for Description
  $('.description_edit').click(editDescriptionDialog);
  $('.close-description-dialog').click(closeDescriptionDialog);

  // Edit dialog for Description
  $('.preferences_edit').click(editPreferencesDialog);
  $('.close-preferences-dialog').click(closePreferencesDialog);

  // Edit dialog for Repositories and Packages
  $('.repository_edit').click(editRepositoryDialog);
  $('.package_edit').click(editPackageDialog);
  $('#kiwi-repositories-list .close-dialog, #kiwi-packages-list .close-dialog').click(closeDialog);
  $('.revert-dialog').click(revertDialog);
  $('.kiwi-repository-mode-toggle').click(repositoryModeToggle);
  $('#kiwi-repositories-list .kiwi_list_item, #kiwi-packages-list .kiwi_list_item').hover(hoverListItem, hoverListItem);
  $('[name=target_project]').each(function() {
    kiwiRepositoriesSetupAutocomplete($(this).parents('.nested-fields'));
  });
  $('#kiwi-packages-list .nested-fields').each(function() {
    kiwiPackagesSetupAutocomplete($(this));
  });

  // After inserting new repositories add the Callbacks
  $('#kiwi-repositories-list').on('cocoon:after-insert', function(e, addedFields) {
    var lastOrder = 0;
    var orders = $(this).find("[id$='order']");
    var lastNode = $(orders[orders.length - 2]);
    if (lastNode.length > 0) {
      lastOrder = parseInt(lastNode.val());
    }
    $(addedFields).find("[id$='order']").val(lastOrder + 1);
    $('.overlay').show();
    $(addedFields).find('.repository_edit').click(editRepositoryDialog);
    $(addedFields).find('.close-dialog').click(closeDialog);
    $(addedFields).find('.revert-dialog').click(revertDialog);
    $(addedFields).find('.kiwi-repository-mode-toggle').click(repositoryModeToggle);
    $(addedFields).find('.kiwi_list_item').hover(hoverListItem, hoverListItem);
    kiwiRepositoriesSetupAutocomplete($(addedFields));
    $('#no-repositories').hide();
  });

  $('#kiwi-repositories-list').on('cocoon:after-remove', function() {
    if ($(this).find('.nested-fields:visible').size() === 0) {
      $('#no-repositories').show();
    }
  });

  // After inserting new packages add the Callbacks
  $('#kiwi-packages-list').on('cocoon:after-insert', function(e, addedFields) {
    $('.overlay').show();
    $(addedFields).find('.package_edit').click(editPackageDialog);
    $(addedFields).find('.close-dialog').click(closeDialog);
    $(addedFields).find('.revert-dialog').click(revertDialog);
    $(addedFields).find('.kiwi_list_item').hover(hoverListItem, hoverListItem);
    kiwiPackagesSetupAutocomplete($(addedFields));
    $('#no-packages').hide();
  });

  $('#kiwi-packages-list').on('cocoon:after-remove', function() {
    if ($(this).find('.nested-fields:visible').size() === 0) {
      $('#no-packages').show();
    }
  });
});
