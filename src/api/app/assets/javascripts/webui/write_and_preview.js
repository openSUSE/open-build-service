$(document).ready(function(){
  $('.write-and-preview').on('show.bs.tab', '.preview-message-tab:not(.active)', function (e) {
      var messageContainer = $(e.target).closest('.write-and-preview');
      var messageText = messageContainer.find('.message-field').val();
      var messagePreview = messageContainer.find('.message-preview');
      if (messageText) {
        $.ajax({
          method: 'POST',
          url: $(this).data('previewMessageUrl'),
          dataType: 'json',
          data: { 'status_message[message]': messageText },
          success: function(data) {
            messagePreview.html(data.markdown);
          },
          error: function() {
            messagePreview.html('Error loading markdown preview');
          }
        });
      } else {
        messagePreview.html('Nothing to preview');
      }
  });
});
