function collectDeleteConfirmationModalsAndSetValues() { // jshint ignore:line
  $.each(modalIds(), function( _index, modalId ) {
    setValuesOnDeleteConfirmationDialog(modalId);
  });
}

function modalIds() {
  var targets = $('a[data-bs-toggle="modal"][data-bs-target^="#delete"]').toArray().map(
    function(e) { return $(e).data('bs-target');
  });

  return $.unique(targets);
}

function setValuesOnDeleteConfirmationDialog(modalId) {
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
