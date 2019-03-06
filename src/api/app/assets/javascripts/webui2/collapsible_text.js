$(document).ready(function() {
  $('.obs-collapsible-textbox').on('click', function() {
    var selectedText = document.getSelection().toString();
    if(!selectedText) {
      var collapsibleLink = $(this).find('.obs-collapsible-link');
      var showText = (collapsibleLink.attr('title') === 'Show more' ) ? 'Show less' : 'Show more';

      $(this).find('.obs-collapsible-text, .obs-collapsible-link').toggleClass('obs-collapsed obs-uncollapsed');
      collapsibleLink.attr('title', showText);
    }
  });
});
