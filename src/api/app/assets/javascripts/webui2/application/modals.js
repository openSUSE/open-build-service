function setModal(link, modalTarget) {
  var modal = $(modalTarget);

  $(link).click(function() {
    modal.addClass('is-active');
  });

  modal.find('.modal-background, .modal-close, .modal-card-head .delete, .modal-card-foot .button.cancel').click(function (event) {
    event.preventDefault();
    modal.removeClass('is-active');
  });

  $(document.documentElement).keydown(function (event) {
    var e = event || window.event;
    if (e.keyCode === 27) {
      modal.removeClass('is-active');
    }
  });
}
