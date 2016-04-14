$(document).on(
  'click',
  'a[data-repository-edit]',
  function(e) {
    e.preventDefault();
    $(this).
      parent('.edit-repository-field').
      hide().
      next('.edit-repository-container').
      show();
});
