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

$(document).ready(function(){
  $('.comments-list').on('keyup click', '.comment-field', function() {
    resizeTextarea(this);
  });

  $('.comments-list').on('ajax:complete', '.new-comment-form', function(_, data) {
    var $commentsList = $(this).closest('.comments-list');

    $commentsList.html(data.responseText);
    updateCommentCounter($commentsList.data('comment-counter'), 1);
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
});
