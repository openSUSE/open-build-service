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
  $('.comment_new').on('ajax:complete', function(event, data) {
    $('#comments').html(data.responseText);

    // as the comments get loaded again, the jQuery bindings are lost. We need to reload them.
    reloadCommentBindings();
  });
}

$(document).ready(function(){
  reloadCommentBindings();

  $('.comments').on('keyup click', '.comment-field', function() {
    sz(this);
  });
});
