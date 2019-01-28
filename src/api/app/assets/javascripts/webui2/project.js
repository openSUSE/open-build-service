function projectsDatatable() { // jshint ignore:line
  $('#projects-datatable').dataTable({
    "processing": true,
    "serverSide": true,
    "ajax": $('#projects-datatable').data('source'),
    "pagingType": "full_numbers",
    "columns": [
      {"data": "name"},
      {"data": "title"}
    ]
    // pagingType is optional, if you want full pagination controls.
    // Check dataTables documentation to learn more about
    // available options.
  });
}
