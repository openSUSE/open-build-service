var activate_in_place_editing = function() {
    var $edit_button = $('#in-place-editing-edit-button');
    var $cancel_button = $('#in-place-editing-cancel-button');
    var $editing_form_wrapper = $('.in-place-editing-form-wrapper');
    var $editing_content_wrapper = $('.in-place-editing-content');
    var $editing_form = $('#in-place-editing-form');
    $edit_button.on('click', function(event) {
        // Show the editing form and the cancel button
        $editing_form_wrapper.removeClass('d-none');
        $cancel_button.removeClass('d-none');
        // Hide the "read only" content and the edit button
        $editing_content_wrapper.addClass('d-none');
        $edit_button.addClass('d-none');
    });
    $editing_form.on('ajax:success', function(event, data, status, xhr) {
        // Hide the editing form and the cancel button
        $editing_form_wrapper.addClass('d-none');
        $cancel_button.addClass('d-none');
        // Update and show the read only content with the updated content
        // from the controller and show the edit button back
        $editing_content_wrapper.html(xhr.responseText).removeClass('d-none');
        $edit_button.removeClass('d-none');
    });
    $cancel_button.on('click', function(event) {
        // Hide the editing form and the cancel button
        $editing_form_wrapper.addClass('d-none');
        $cancel_button.addClass('d-none');
        // Show the read only content and the edit button back
        $editing_content_wrapper.removeClass('d-none');
        $edit_button.removeClass('d-none');
    });
};
