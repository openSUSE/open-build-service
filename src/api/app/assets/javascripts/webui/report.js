function collectReportModalsAndSetValues() { // jshint ignore:line
  $.each(modalIdsForReport(), function( _index, modalId ) {
    setValuesOnReportDialog(modalId);
  });
}

// TODO: This function is overlapping with the function in delete_confirmation_dialog.js#modalIds
function modalIdsForReport() {
  var targets = $('a[data-bs-toggle="modal"][data-bs-target^="#report"]').toArray().map(
    function(e) { return $(e).data('bs-target');
  });

  return $.unique(targets);
}

function setValuesOnReportDialog(modalId) {
  $(modalId).on('show.bs.modal', function (event) {
    var link = $(event.relatedTarget);
    var modal = $(this);

    if (typeof(link.data('modal-title')) !== 'undefined') {
      modal.find('.modal-title').text(link.data('modal-title'));
    }

    if (typeof(link.data('reportable-id')) !== 'undefined') {
      modal.find('#report_reportable_id').val(link.data('reportable-id'));
    }

    if (typeof(link.data('reportable-type')) !== 'undefined') {
      modal.find('#report_reportable_type').val(link.data('reportable-type'));
      modal.find('.reportable_type').text(link.data('reportable-type'));
    }

    modal.find('#link_id').val(link.attr('id'));
  });
}

/* exported hideReportButton */
function hideReportButton(element) {
  $(element).addClass('d-none');
}

$(document).ready(function(){
  $('#report-category').on('change', '.form-check-input', function(e) {
    $('#report-reason').toggleClass('d-none', ( e.target.value !== 'other' ));
  });
});
