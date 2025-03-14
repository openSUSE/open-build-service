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
      var reportableType = link.data('reportable-type');
      var reportableIsComment = reportableType === 'Comment';

      modal.find('#report_reportable_type').val(reportableType);
      modal.find('.reportable_type').text(reportableType === "BsRequest" ? 'Request' : reportableType);
      modal.find('#report-comment-author-container').toggle(reportableIsComment);
      modal.find('#report_comment_author').prop('disabled', !reportableIsComment);
    }

    modal.find('#link_id').val(link.attr('id'));
  });
}

/* exported hideReportButton */
function hideReportButton(element) {
  $(element).addClass('d-none');
}

/* exported showYouReportedMessage */
function showYouReportedMessage(reportLinkId, reportableType, reportableId, message) {
  switch(reportableType) {
    case 'Comment':
      // Comments differ depending on where they are, so this is why we have two ways. If an element isn't found, nothing will happen...
      // For comments on a project/package - In the comment, insert the 'You reported the comment' message after 'User X wrote (...)'
      $('#comment-' + reportableId + '-user').after(message);
      // For comments on a request - In the comment, insert the 'You reported the comment' message before the comment body
      $('#comment-' + reportableId + '-body').prepend(message);
      break;
    case 'Project':
    case 'Package':
      // The 'You reported the project/package' is displayed in the side links of the project/package
      $('ul.side_links').append(message);
      break;
    case 'User':
      // The 'You reported the user' message is displayed after the (now) hidden 'Report' link
      $(reportLinkId).after(message);
      break;
  }
}
