$(document).ready(function() {
  // Show reload button when tab is changed
  $('#requests li a').click(function() {
    $(this).parent().parent().find('.result_reload').hide();
    $(this).siblings('.result_reload').show();
  });
});
