$(document).ready(function() {
  $(document).on('keydown', function(e) {
    if (e.key === '/' && !$(e.target).is('input, textarea, select, [contenteditable]')) {
      const $inputSearchText = $('input[name="search_text"]');

      if ($inputSearchText.length) {
        e.preventDefault();
        $inputSearchText.focus().select();
      }
    }
  });
});
