function resizeTextarea(textarea) { // jshint ignore:line
  var heightPerRow = Math.ceil(textarea.clientHeight / textarea.rows);
  var linesOfText = Math.ceil(textarea.scrollHeight / heightPerRow);
  var rowsToIncrease = linesOfText - textarea.rows;

  textarea.rows += rowsToIncrease;
}

function updateCommentCounter(selector, count) {
  if (selector !== undefined && selector !== null && selector !== '') {
    var oldValue = $(selector).text();

    $(selector).text(parseInt(oldValue) + count);
  }
}

function validateForm(e) {
  var submitButton = $(e.target).closest('[class*="-comment-form"]').find('input[type="submit"]');
  submitButton.prop('disabled', !$(e.target).val());
}

function handlingCommentEvents() {
  // Disable submit button if textarea is empty and enable otherwise
  const commentFieldSelector = `.comments-list .comment-field, .comment_new .comment-field,
                                .timeline .comment-field, .diff .comment-field,
                                .diff-accordion .comment-field`;
  $(document).on('input', commentFieldSelector, function(e) {
    validateForm(e);
    resizeTextarea(this);
  });

  // This is being used by the legacy request view comment form to capture the rendered template
  // from the controller and replace the whole .comments-list with it
  const commentListSelector = '.comments-list .post-comment-form, .comments-list .put-comment-form, .comments-list .moderate-form';
  $(document).on('ajax:complete', commentListSelector, function(_, data) {
    var $commentsList = $(this).closest('.comments-list');

    $commentsList.html(data.responseText);
    updateCommentCounter($commentsList.data('comment-counter'), 1);
  });

  // This is being used to render only the comment thread for a reply by the beta request show view
  const timelineDiffSelector = `.timeline .post-comment-form, .timeline .put-comment-form, .timeline .moderate-form,
                                .diff .post-comment-form, .diff .put-comment-form, .diff .moderate-form,
                                .diff-accordion .post-comment-form, .diff-accordion .put-comment-form,
                                .diff-accordion .moderate-form`;
  $(document).on('ajax:complete', timelineDiffSelector, function(_, data) {
    $(this).closest('.comments-thread').html(data.responseText);
  });

  // This is being used to render a new root comment by the beta request show view
  $(document).on('ajax:complete', '.comment_new .post-comment-form', function(_, data) {
    $(this).closest('.comment_new').prev().append(
      '<div class="timeline-item">' +
        '<div class="comments-thread">' +
          data.responseText +
        '</div>' +
      '</div>'
    );
    $(this).trigger("reset");
  });

  // This is used to delete a comment from the legacy request view
  $(document).on('ajax:complete', '.comments-list .delete-comment-form', function(_, data) {
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

  // This is used to delete comments from the beta request show view, we are not gonna get an updated comment thread like
  $(document).on('ajax:complete', '#delete-comment-modal form', function(_, data) {
    var $commentId = $(this).attr('action').split('/').slice(-1),
        $commentsList = $('[name=comment-' + $commentId + ']').closest('.comments-thread'),
        $form = $('#delete-comment-modal');

    $form.modal('hide');
    // We have to wait until the modal is hidden to properly remove the dialog UI
    $form.on('hidden.bs.modal', function () {
      $commentsList.html(data.responseText);
    });
  });

  // Toggle visibility of reply form of the same comment
  $(document).on('click', '[id*="edit_button_of_"]', function (e) {
    const idNumber = $(e.target).attr('id').split('edit_button_of_')[1];
    $('#reply_form_of_' + idNumber + ' .cancel-comment').click();
  });
  // Toggle visibility of edit form of the same comment]
  $(document).on('click', '[id*="reply_button_of_"]', function (e) {
    const idNumber = $(e.target).attr('id').split('reply_button_of_')[1];
    $('#edit_form_of_' + idNumber + ' .cancel-comment').click();
  });

  $(document).on('click', '.cancel-comment', function (e) {
    $(e.target).closest('.collapse').collapse('hide');
  });
}

$(document).ready(function(){
  handlingCommentEvents();
});
