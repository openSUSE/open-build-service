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

/* HTML tags structure for tabs:
.header-tabs
  %ul
    %li
      %a Tab1
    %li
      %a Tab2
    %li
      %a Tab3
.content-tabs
  .content-tab
    Content for Tab1
  .content-tab
    Content for Tab2 - this has a nexted tab
    .header-tabs
      %ul
        %li
          %a Tab1
        %li
          %a Tab2
    .content-tabs
      .content-tab
        Content for Tab1
      .content-tab
        Content for Tab2
  .content-tab
    Content for Tab3  
*/
