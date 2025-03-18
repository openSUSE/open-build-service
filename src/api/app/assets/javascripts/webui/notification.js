function setSelectAllCheckbox() {
  $(document).on('change', '#select-all-notifications', function() {
    var checkboxes = $(this).closest('form').find('input[type=checkbox]');
    checkboxes.prop('checked', $(this).is(':checked'));
  });
}

function setCheckboxCounterAndSubmitButton() {
  var amountBoxesChecked = 0;
  $("input[id^='notification_ids_']").each(function() {
    if($(this).is(':checked')){
      amountBoxesChecked += 1;
    }
  });

  if(amountBoxesChecked <= 0) {
    $('#read-button').prop('disabled', true);
    $('#unread-button').prop('disabled', true);
    $('#select-all-label').text('Select All');
  } else {
    $('#read-button').prop('disabled', false);
    $('#unread-button').prop('disabled', false);
    $('#select-all-label').text(amountBoxesChecked + ' selected');
  }
}

function handleNotificationCheckboxSelection() { // jshint ignore:line
  setCheckboxCounterAndSubmitButton();
  setSelectAllCheckbox();
  $(document).on('change', 'input[type="checkbox"]', function() {
    setCheckboxCounterAndSubmitButton();
  });
}
