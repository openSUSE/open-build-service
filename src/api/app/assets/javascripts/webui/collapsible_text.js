var activateCollapsibleText = function() {
  $('.obs-collapsible-textbox').on('click', function(event) {
    var selectedText = document.getSelection().toString();
    if(!selectedText) {
      $(this).find('.obs-collapsible-text').toggleClass('expanded');
      $(this).find('.show-content').toggleClass('more less');
    }
    // This is added to avoid triggering in-place-editing behaviour when having
    // collapsible text added in the form
    event.stopPropagation();
  });

  $('.obs-collapsible-text').each(function(_index, element){
    if (element.scrollHeight > element.offsetHeight) {
      var $link = $('<a href="javascript:void(0)" class="show-content more"><i class="fa"></i></a>');
      $(element).after($link);
    }
  });
};
