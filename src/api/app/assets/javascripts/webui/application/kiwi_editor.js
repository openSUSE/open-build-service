var canSave = false;

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
  $('#kiwi-image-update-form-save').addClass('enabled');
}

function editDialog(){
  var fields = $(this).parents('.nested-fields');
  var dialog = fields.find('.dialog');
  dialog.removeClass('hidden');
  $('.overlay').show();
}

function closeDialog() {
  var fields = $(this).parents('.nested-fields');
  var is_repository = fields.parents('#kiwi-repositories-list').size() == 1;
  var name = fields.find('.kiwi_element_name');
  var dialog = fields.find('.dialog');
  
  if(is_repository) {
    var source_path = dialog.find("[id$='source_path']");
    if(source_path.val() != '') {
      var alias = dialog.find("[id$='alias']");
      if (alias.val() != '') {
        name.text(alias.val());
      }
      else {
        name.text(source_path.val().replace(/\//g, '_'));
      }
    }
    else {
      fields.find(".ui-state-error").removeClass('hidden');
      return false;
    }
  }
  else {
    var namePackage = dialog.find("[id$='name']").val();
    if(namePackage != '') {
      name.text(namePackage);
    }
    else {
      fields.find(".ui-state-error").removeClass('hidden');
      return false;
    }
  }
  
  fields.find(".ui-state-error").addClass('hidden');
  $('.overlay').hide();
  dialog.addClass('hidden');
}

function hoverListItem() {
  $(this).find('.kiwi_actions').toggle();
}

$(document).ready(function(){
  // Save image
  $('#kiwi-image-update-form-save').click(saveImage);

  // Enable save button
  $('#kiwi-image-update-form').change(enableSave);
  $('.remove_fields').click(enableSave);

  // Edit dialog for Repositories and Packages
  $('.repository_edit, .package_edit').click(editDialog);
  $('#kiwi-repositories-list .close-dialog, #kiwi-packages-list .close-dialog').click(closeDialog);
  $('#kiwi-repositories-list .kiwi_list_item, #kiwi-packages-list .kiwi_list_item').hover(hoverListItem, hoverListItem);

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
    $(addedFields).find('.repository_edit').click(editDialog);
    $(addedFields).find('.close-dialog').click(closeDialog);
    $(addedFields).find('.kiwi_list_item').hover(hoverListItem, hoverListItem);
  });

  // After inserting new packages add the Callbacks
  $('#kiwi-packages-list').on('cocoon:after-insert', function(e, addedFields) {
    $('.overlay').show();
    $(addedFields).find('.package_edit').click(editDialog);
    $(addedFields).find('.close-dialog').click(closeDialog);
    $(addedFields).find('.kiwi_list_item').hover(hoverListItem, hoverListItem);
  });
});
