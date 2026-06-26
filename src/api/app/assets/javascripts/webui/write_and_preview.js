function attachPreviewMessageOnCommentBoxes() {
  $('.write-and-preview').off('show.bs.tab', '.preview-message-tab:not(.active)');
  $('.write-and-preview').on('show.bs.tab', '.preview-message-tab:not(.active)', function (e) {
      var messageContainer = $(e.target).closest('.write-and-preview');
      var messageText = messageContainer.find('.message-field').val();
      var messagePreview = messageContainer.find('.message-preview');
      if (messageText) {
        // This is done like this because we cannot set keys from variables in the object definition
        var data = {};
        data[messageContainer.data('messageBodyParam')] = messageText;

        $.ajax({
          method: 'POST',
          url: messageContainer.data('previewMessageUrl'),
          dataType: 'json',
          data: data,
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
}

$(document).ready(function(){
  attachPreviewMessageOnCommentBoxes();
});
