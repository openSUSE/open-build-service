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
  }
);

$(document).on(
  'click',
  'a[data-dod-repository-edit]',
  function(e) {
    e.preventDefault();
    $(this).
      parent('.edit-dod-repository-link-container').
      hide().
      next('.edit-dod-repository-form').
      show();
  }
);

$(document).on(
  'click',
  'a[data-dod-repository-add]',
  function(e) {
    e.preventDefault();
    $(this).
      parent('.add-dod-repository-link-container').
      hide().
      next('.add-dod-repository-form').
      show();
  }
);

$(document).on(
  'click',
  '#add-dod-repository-link',
  function(e) {
    e.preventDefault();
    $(this).hide();
    $('.add-dod-repository-form').slideDown();
  }
);
