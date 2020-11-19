function resizeTextarea(textarea) { // jshint ignore:line
  var textLines = textarea.value.split('\n');
  var neededRows = 1;
  for (var x = 0; x < textLines.length; x++) {
    if (textLines[x].length >= textarea.cols) neededRows += Math.floor(textLines[x].length / textarea.cols);
  }
  neededRows += textLines.length;
  if (neededRows > textarea.rows) textarea.rows = neededRows;
}

function updateCommentCounter(selector, count) {
  var oldValue = $(selector).text();

  $(selector).text(parseInt(oldValue) + count);
}

function validateForm(e) {
  var submitButton = $(e.target).closest('[class*="-comment-form"]').find('input[type="submit"]');
  submitButton.prop('disabled', !$(e.target).val());
}

$(document).ready(function(){
  // Disable submit button if textarea is empty and enable otherwise
  $('.comments-list').on('keyup', '.comment-field', function(e) {
    validateForm(e);
  });

  $('.comments-list').on('keyup click', '.comment-field', function() {
    resizeTextarea(this);
  });

  $('.comments-list').on('ajax:complete', '.post-comment-form', function(_, data) {
    var $commentsList = $(this).closest('.comments-list');

    $commentsList.html(data.responseText);
    updateCommentCounter($commentsList.data('comment-counter'), 1);
  });

  $('.comments-list').on('ajax:complete', '.put-comment-form', function(_, data) {
    var $commentsList = $(this).closest('.comments-list');

    $commentsList.html(data.responseText);
  });

  $('.comments-list').on('ajax:complete', '.delete-comment-form', function(_, data) {
    var $this = $(this),
        $commentsList = $this.closest('.comments-list'),
        $form = $('#delete-comment-modal-' + $this.data('commentId'));

    $form.modal('hide');
    // We have to wait until the modal is hidden to properly remove the dialog UI
    $form.on('hidden.bs.modal', function () {
      updateCommentCounter($commentsList.data('comment-counter'), -1);
      $commentsList.html(data.responseText);
    });
  });

  $('body').on('click', 'button[id*="edit_button_of_"]', function (e) {
    var closest = $(e.target).parent().parent().find('button[id*="reply_button_of_"]');
    if (!closest.hasClass('collapsed'))
      closest.trigger('click');
  });

  $('body').on('click', 'button[id*="reply_button_of_"]', function (e) {
    var closest = $(e.target).parent().parent().find('button[id*="edit_button_of_"]');
    if (!closest.hasClass('collapsed'))
      closest.trigger('click');
  });

  $('body').on('click', '.cancel-comment', function (e) {
    $(e.target).closest('.collapse').collapse('hide');
  });

  $('.comments-list').on('click', '.preview-comment-tab:not(.active)', function (e) {
      var commentContainer = $(e.target).closest('[class*="-comment-form"]');
      var commentBody = commentContainer.find('.comment-field').val();
      var commentPreview = commentContainer.find('.comment-preview');
      if (commentBody) {
        $.ajax({
          method: 'POST',
          url: commentContainer.data('previewCommentUrl'),
          dataType: 'json',
          data: { 'comment[body]': commentBody },
          success: function(data) {
            commentPreview.html(data.markdown);
          },
          error: function() {
            commentPreview.html('Error loading markdown preview');
          }
        });
      } else {
        commentPreview.html('Nothing to preview');
      }
  });
});
