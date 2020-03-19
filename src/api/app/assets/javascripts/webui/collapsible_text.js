$(document).ready(function() {
  setCollapsible();
});

function setCollapsible() {
  $('.obs-collapsible-textbox').on('click', function() {
    var selectedText = document.getSelection().toString();
    if(!selectedText) {
      $(this).find('.obs-collapsible-text').toggleClass('expanded');
      $(this).find('.show-content').toggleClass('more less');
    }
  });

  $('.obs-collapsible-text').each(function(_index, element){
    if (element.scrollHeight > element.offsetHeight) {
      var $link = $('<a href="javascript:void(0)" class="show-content more"><i class="fa"></i></a>');
      $(element).after($link);
    }
  });
}
