function setCollapsible() { // jshint ignore:line
  $('.obs-collapsible-textbox').each(function() {
    var container = $(this);
    var textBox = container.find('.obs-collapsible-text');
    var showButton = container.find('.show-content');

    // Add the event if it wasn't already added
    if (container.hasClass('vanilla-textbox-to-collapse')) {
      container.on('click', function() {
        if(!document.getSelection().toString()) {
          textBox.toggleClass('expanded');
          showButton.toggleClass('more less');
        }
      });
      // Make sure to not add the event twice by removing the target class
      container.removeClass('vanilla-textbox-to-collapse');
    }

    // Make sure to not add the button twice and only if it makes sense to
    if (showButton.length === 0 && textBox.prop('scrollHeight') > textBox.prop('offsetHeight')) {
      showButton = $('<a href="javascript:void(0)" class="show-content more"><i class="fa"></i></a>');
      textBox.after(showButton);
    }
  });
}
