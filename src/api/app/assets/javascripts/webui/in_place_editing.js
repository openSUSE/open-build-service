var activate_in_place_editing = function($hook) {
  var element_id = $hook.attr('data-id');
  var id_of_element_to_refresh = $hook.attr('data-refresh-target-id');
  // This element will receive the updated content from the controller
  var $element_to_refresh = $(`#${id_of_element_to_refresh}`);
  var $triggering_wrapper = $hook.find('.triggering-wrapper');
  var $triggering_element = $(`#${element_id}-trigger`);
  var $form_element = $(`#${element_id}-form`);
  var $input_element = $(`#${element_id}-input`);
  var $cancel_button = $(`#${element_id}-cancel`);

  var toggler = function() {
    $triggering_wrapper.toggleClass('d-none');
    $triggering_element.toggleClass('d-none');
    $form_element.toggleClass('d-none');
  };
  var toggler_and_focus = function() {
    toggler();
    $input_element.focus();
  };

  $form_element.on("ajax:success", function(event, data, status, xhr) {
    $element_to_refresh.html(xhr.responseText);
  }).on("ajax:complete", function(event, xhr, status) {
    toggler();
  });

  $triggering_element.bind('click', toggler_and_focus);
  $triggering_wrapper.bind('click', toggler_and_focus);
  $cancel_button.bind('click', function(event) {
    toggler(); 
    event.preventDefault();
  });
};
