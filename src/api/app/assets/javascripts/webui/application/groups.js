$(document).ready(function(){
  $('#group-members-table').dataTable();
  $('.header-tabs li a').click(function() {
    // Select tab
    $(this).closest('ul').children('li').removeClass('selected');
    $(this).parent().addClass('selected');
    // Show and hide content
    var id = $(this).data("id");
    $('.table-container').addClass('hidden');
    $('#' + id).removeClass('hidden');
    // Show reload button when tab is changed
    $(this).parent().parent().find('.result_reload').hide();
    $(this).siblings('.result_reload').show();
  });
});
