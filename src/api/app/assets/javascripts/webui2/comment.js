// Expand the comment textarea to fit the text
// as it's being typed.
function sz(t) { // jshint ignore:line
  var a = t.value.split('\n');
  var b = 1;
  for (var x = 0; x < a.length; x++) {
    if (a[x].length >= t.cols) b += Math.floor(a[x].length / t.cols);
  }
  b += a.length;
  if (b > t.rows) t.rows = b;
}

function updateCommentCounter(selector, count) {
  var oldValue = $(selector).text();

  $(selector).text(parseInt(oldValue) + count);
}

$(document).ready(function(){
  $('.comments-list').on('keyup click', '.comment-field', function() {
    sz(this);
  });

  $('.comments-list').on('ajax:complete', '.new-comment-form', function(_, data) {
    var $commentsList = $(this).closest('.comments-list');

    $commentsList.html(data.responseText);
    updateCommentCounter($commentsList.data('comment-counter'), 1);
  });

  $('.comments-list').on('ajax:complete', '.delete-comment-form', function(_, data) {
    var $this = $(this),
        $commentsList = $this.closest('.comments-list'),
        formSelector = '#delete-comment-modal-' + $this.data('commentId');

    $(formSelector).modal('hide');
    // We have to wait until the modal is hidden to properly remove the dialog UI
    $(formSelector).on('hidden.bs.modal', function () {
      updateCommentCounter($commentsList.data('comment-counter'), -1);
      $commentsList.html(data.responseText);
    });
  });
});
