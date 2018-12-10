function setSpinnersForFlags() { // jshint ignore:line
  $(document).on('click','.popover_flag_action', function() {
    var flag = $(this).data('flag-id');
    var icon = $('div[id="' + flag + '"] a');
    icon.addClass('d-none');
    icon.next().removeClass('d-none');
  });
}

function setRepoCheckbox() { // jshint ignore:line
  $('.repocheckbox').click(function() {
    var id = $(this).attr('id');
    var $form;
    if($(this).is(':checked')) {
      $form = $('#' + id + '_create');
    } else {
      $form = $('#' + id + '_destroy');
    }
    $form.submit();
  });
}
