$(document).ready(function(){
  $('.tabs li a span.tab-title').click(function() {
    var li = $(this).parents('li');
    // Select tab
    li.siblings('li').removeClass('is-active');
    li.addClass('is-active');
    // Show and hide content
    var id = li.data("id");
    li.closest('.tabs').next('.box.with-tabs').find('.content-tab').addClass('is-hidden');
    $('#' + id).removeClass('is-hidden');
    // Show reload button when tab is changed
    li.siblings().find('.result_reload').addClass('is-hidden');
    li.find('.result_reload').removeClass('is-hidden');
  });
});
