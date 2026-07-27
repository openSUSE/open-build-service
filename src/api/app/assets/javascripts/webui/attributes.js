$(document).ready(function() {
  $('#attrib_attrib_type_id').change(function() {
    $("[id^='attribute_type-description-']:visible").addClass('d-none');
    $('#attribute_type-description-' + $(this).val()).removeClass('d-none');
  });

  $('#attributes').dataTable({
    responsive: true,
    info: false,
    searching: false,
    paging: false,
    ordering: false,
    columnDefs: [
      { className: 'dtr-control', targets: 0 }
    ]
  });
});
