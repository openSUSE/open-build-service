function setValuesOnDeleteConfirmationDialog(modalId) { // jshint ignore:line
  $(modalId).on('show.bs.modal', function (event) {
    var link = $(event.relatedTarget);
    var modal = $(this);

    if (typeof(link.data('modal-title')) !== 'undefined') {
      modal.find('.modal-title').text(link.data('modal-title'));
    }

    if (typeof(link.data('confirmation-text')) !== 'undefined') {
      modal.find('.confirmation-text').text(link.data('confirmation-text'));
    }

    if (typeof(link.data('action')) !== 'undefined') {
      modal.find('form').attr('action', link.data('action'));
    }

    if (typeof(link.data('method')) !== 'undefined') {
      modal.find('form').attr('action', link.data('method'));
    }

    if (typeof(link.data('remote')) !== 'undefined') {
      modal.find('form').attr('action', link.data('remote'));
    }
  });
}
