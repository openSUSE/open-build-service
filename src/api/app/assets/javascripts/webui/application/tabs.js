$(document).ready(function(){
  $('.header-tabs li a').click(function() {
    // Select tab
    $(this).closest('ul').children('li').removeClass('selected');
    $(this).parent().addClass('selected');
    // Show and hide content
    var id = $(this).data("id");
    $(this).closest('.header-tabs').next('.content-tabs').find('.content-tab').addClass('hidden');
    $('#' + id).removeClass('hidden');
    // Show reload button when tab is changed
    $(this).closest('ul').find('.result_reload').hide();
    $(this).siblings('.result_reload').show();
  });
});
