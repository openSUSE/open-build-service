$(document).on(
  'click',
  'a[data-repository-edit]',
  function() {
    $(this).
      parent('.edit-repository-field').
      hide().
      next('.edit-repository-container').
      show();
});
