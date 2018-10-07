function setSpinnersForFlags() { // jshint ignore:line
  $(document).on('click','.popover_flag_action', function() {
    var flag = $(this).data('flag-id');
    var icon = $('div[id="' + flag + '"] a');
    icon.addClass('d-none');
    icon.next().removeClass('d-none');
  });
}
