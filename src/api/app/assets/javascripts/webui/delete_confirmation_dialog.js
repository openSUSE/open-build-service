document.addEventListener("turbo:load", function () {
  $(document).on('show.bs.modal', '.modal[id^="delete"]', function (event) {
    const link = $(event.relatedTarget);
    const modal = $(this);

    if (link.data('modal-title') !== undefined) {
      modal.find('.modal-title').text(link.data('modal-title'));
    }

    if (link.data('confirmation-text') !== undefined) {
      modal.find('.confirmation-text').text(link.data('confirmation-text'));
    }

    if (link.data('action') !== undefined) {
      modal.find('form').attr('action', link.data('action'));
    }

    if (link.data('method') !== undefined) {
      modal.find('form').attr('method', link.data('method'));
    }

    if (link.data('remote') !== undefined) {
      modal.find('form').data('remote', link.data('remote'));
    }
  });
});

