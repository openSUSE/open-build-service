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

function reloadCommentBindings() {
  $('a.supersed_comments_link').on('click', function(){
    var link = $(this).text();
    $(this).text(link === 'Show outdated comments' ? 'Hide outdated comments' : 'Show outdated comments');
    $(this).parent().siblings('.superseded_comments').toggle();
  });
  $('.togglable_comment').click(function () {
      var toggleid = $(this).data("toggle");
      $("#" + toggleid).toggle();
      $("#" + toggleid).toggleClass('d-none');
      $("#" + toggleid + ' .comment_reply_body').focus();
  });

  // prevent duplicate comment submissions
  $('.comment_new').submit(function() {
      $(this).find('input[type="submit"]').prop('disabled', true);
  });

  $('.comment_new').on('ajax:complete', function(event, data) {
    $('#comments').html(data.responseText);

    // as the comments get loaded again, the jQuery bindings are lost. We need to reload them.
    reloadCommentBindings();
  });
}

$(document).ready(function(){
  reloadCommentBindings();
});
