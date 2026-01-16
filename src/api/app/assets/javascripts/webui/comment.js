function resizeTextarea(textarea) {
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

function commentErrorFlash(text) {
  const flash = document.getElementById('flash');
  const container = flash.querySelector('.col-12');
  const alert = document.createElement('div');
  alert.classList.add('alert', 'alert-danger');
  alert.innerText = text;
  container.appendChild(alert);
}

function validateForm(e) {
  var submitButton = $(e.target).closest('[class*="-comment-form"]').find('input[type="submit"]');
  submitButton.prop('disabled', !$(e.target).val());
}

function handlingCommentEvents() {
  // Disable submit button if textarea is empty and enable otherwise
  $(document).on('input', '.write-and-preview textarea', function(e) {
    validateForm(e);
    resizeTextarea(this);
  });

  // This is being used by the legacy request view comment form to capture the rendered template
  // from the controller and replace the whole .comments-list with it
  const commentListSelector = '.comments-list .post-comment-form, .comments-list .put-comment-form, .comments-list .moderate-form';
  $(document).on('ajax:complete', commentListSelector, function(_, data) {
    if (data.status !== 200) {
      commentErrorFlash('Failed to submit the comment.');
      return;
    }
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
    if (data.status !== 200) {
      commentErrorFlash('Failed to submit the comment.');
      return;
    }
    $(this).closest('.comments-thread').html(data.responseText);
  });

  // This is being used to render a new root comment by the beta request show view
  $(document).on('ajax:complete', '.comment_new .post-comment-form', function(_, data) {
    if (data.status !== 200) {
      commentErrorFlash('Failed to create a comment.');
      return;
    }
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
    if (data.status !== 200) {
      commentErrorFlash('Failed to delete the comment.');
      return;
    }
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
    if (data.status !== 200) {
      commentErrorFlash('Failed to delete the comment.');
      return;
    }
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

function draftComments(formId) { // jshint ignore:line
  let commentForm = document.getElementById(formId);
  if (!commentForm) return;

  var submitButton = commentForm.querySelector('input[type="submit"]');
  var commentTextArea = commentForm.getElementsByTagName("textarea")[0];
  var commentableType = commentForm.querySelector('[name="commentable_type"]').value;
  var commentableId = commentForm.querySelector('[name="commentable_id"]').value;
  var diffFileIndex = null;
  var diffLineNumber = null;
  var parentElementId = '';
  var parentElement = null;
  var intId = formId.match(/\d+/);
  if (intId) {
    intId = parseInt(intId[0], 10);
  }
  if (formId.includes("edit")) {
    parentElementId = `edit_form_of_${intId}`;
  } else {
    parentElementId = `reply_form_of_${intId}`;
  }
  parentElement = document.getElementById(parentElementId);

  if (commentForm.querySelector('[name="comment[diff_file_index]"]')) {
    diffFileIndex = commentForm.querySelector('[name="comment[diff_file_index]"]').value;
  }

  if (commentForm.querySelector('[name="comment[diff_line_number]"]')) {
    diffLineNumber = commentForm.querySelector('[name="comment[diff_line_number]"]').value;
  }

  commentTextArea.addEventListener('keyup', (event) => {
    if (diffLineNumber && diffFileIndex) {
      let commentDraft = JSON.stringify({ diffLineNumber: diffLineNumber, diffFileIndex: diffFileIndex, commentDraftText: event.target.value});
      sessionStorage.setItem(`${commentableType}_${commentableId}_${diffFileIndex}_${diffLineNumber}`, commentDraft);
    } else {
      sessionStorage.setItem(formId, event.target.value);
    }
  });

  // insert draft comment into comment form on page load
  if(commentableType.startsWith("BsRequestAction")) {
    if (sessionStorage.getItem(`${commentableType}_${commentableId}_${diffFileIndex}_${diffLineNumber}`)) {
      let draftCommentData = JSON.parse(sessionStorage.getItem(`${commentableType}_${commentableId}_${diffFileIndex}_${diffLineNumber}`));
      commentTextArea.value = draftCommentData.commentDraftText;
    }
  }
  if (sessionStorage.getItem(formId)) {
    if (formId.includes("edit")) {
      document.getElementById(`comment-${intId}-body`).style.display = "none";
    }
    commentTextArea.value = sessionStorage.getItem(formId);
    // Keep the hidden field open
    if (parentElement) {
      parentElement.classList.add('show');
    }
  }
  // Enable `Add comment` button
  if(submitButton){
    submitButton.disabled = false;
  }
}

$(document).on('click', '.cancel-comment', function() {
  var formId = $(this).closest('form').attr('id');
  clearDraftCommentFromSession(formId);
});

// Returns the sessionStorage key or null. Examples of returned values:
//   - new_comment_diff_0_n1_form
//   - BsRequestActionSubmit_70_0_1
//   - null
function sessionStorageKey(formId) {
  if (sessionStorage.getItem(formId) !== null) {
    return formId;
  }

  let commentForm = document.getElementById(formId);
  if (!commentForm) return null;
  var commentableType = commentForm.querySelector('[name="commentable_type"]').value;
  var commentableId = commentForm.querySelector('[name="commentable_id"]').value;
  var diffFileIndex;
  var diffLineNumber;
  if (commentForm.querySelector('[name="comment[diff_file_index]"]')) {
    diffFileIndex = commentForm.querySelector('[name="comment[diff_file_index]"]').value;
  }

  if (commentForm.querySelector('[name="comment[diff_line_number]"]')) {
    diffLineNumber = commentForm.querySelector('[name="comment[diff_line_number]"]').value;
  }

  var compositeKey = `${commentableType}_${commentableId}_${diffFileIndex}_${diffLineNumber}`;
  return sessionStorage.getItem(compositeKey) !== null ? compositeKey : null;
}

// Removes the sessionStorage key-value pair
function clearDraftCommentFromSession(formId) {
  var key = sessionStorageKey(formId);

  if (key !== null && key !== undefined) {
    sessionStorage.removeItem(key);
  }
}

function openInlineCommentFormWithDraftAvailable(commentableType, commentableId) { // jshint ignore:line
  var regex = new RegExp(`${commentableType}_${commentableId}`);

  Object.keys(sessionStorage).filter(function(k) { return regex.test(k); }).forEach(function(k) {
    let draftCommentData = JSON.parse(sessionStorage.getItem(k));
    let draftCommentBoxLink = document.querySelectorAll(`[data-diff-line="${draftCommentData.diffLineNumber}"][data-diff-file-index="${draftCommentData.diffFileIndex}"]`)[0];
    if (draftCommentBoxLink) {
      draftCommentBoxLink.click();
    }
  });
}
