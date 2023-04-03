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
  $('.comments-list,.comment_new,.timeline,.diff').on('keyup', '.comment-field', function(e) {
    validateForm(e);
  });

  $('.comments-list,.comment_new,.timeline,.diff').on('keyup click', '.comment-field', function() {
    resizeTextarea(this);
  });

  // This is being used by the legacy request view comment form to capture the rendered template
  // from the controller and replace the whole .comments-list with it
  $('.comments-list').on('ajax:complete', '.post-comment-form', function(_, data) {
    var $commentsList = $(this).closest('.comments-list');

    $commentsList.html(data.responseText);
    updateCommentCounter($commentsList.data('comment-counter'), 1);
  });

  // This is being used to render only the comment thread for a reply by the beta request show view
  $('.timeline,.diff').on('ajax:complete', '.post-comment-form', function(_, data) {
    $(this).closest('.comments-thread').html(data.responseText);
  });

  // This is being used to render a new root comment by the beta request show view
  $('.comment_new').on('ajax:complete', '.post-comment-form', function(_, data) {
    $(this).closest('.comment_new').prev().append(
      '<div class="timeline-item">' +
        '<div class="comments-thread">' +
          data.responseText +
        '</div>' +
      '</div>'
    );
    $(this).trigger("reset");
  });

  // This is being used to update the comment with the updated content after an edit from the legacy request view
  $('.comments-list').on('ajax:complete', '.put-comment-form', function(_, data) {
    var $commentsList = $(this).closest('.comments-list');

    $commentsList.html(data.responseText);
  });

  // This is being used to update the comment with the updated content after an edit from the beta request show view
  $('.timeline,.diff').on('ajax:complete', '.put-comment-form', function(_, data) {
    $(this).closest('.comments-thread').html(data.responseText);
  });

  // This is used to delete a comment from the legacy request view
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

  // This is used to delete comments from the beta request show view, we are not gonna get an updated comment thread like
  $('body').on('ajax:complete', '#delete-comment-modal form', function(_, data) {
    var $commentId = $(this).attr('action').split('/').slice(-1),
        $commentsList = $('[name=comment-' + $commentId + ']').closest('.comments-thread'),
        $form = $('#delete-comment-modal');

    $form.modal('hide');
    // We have to wait until the modal is hidden to properly remove the dialog UI
    $form.on('hidden.bs.modal', function () {
      $commentsList.html(data.responseText);
    });
  });

  $('body').on('click', '[id*="edit_button_of_"]', function (e) {
    var closest = $(e.target).parent().parent().find('[id*="reply_button_of_"]');
    if (!closest.hasClass('collapsed'))
      closest.trigger('click');
  });

  $('body').on('click', '[id*="reply_button_of_"]', function (e) {
    var closest = $(e.target).parent().parent().find('[id*="edit_button_of_"]');
    if (!closest.hasClass('collapsed'))
      closest.trigger('click');
  });

  $('body').on('click', '.cancel-comment', function (e) {
    $(e.target).closest('.collapse').collapse('hide');
  });

  // This is used to preview comments from the beta request show view: inside timeline thread (.timeline) and outside timeline (body)
  // and also from the legacy request view (.comments-list): inside and outside the thread.
  $('.comments-list, .timeline, body').on('click', '.preview-comment-tab:not(.active)', function (e) {
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
