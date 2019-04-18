//= require datatables/jquery.dataTables
//= require datatables/dataTables.bootstrap4
//= require datatables/extensions/Responsive/dataTables.responsive
//= require datatables/extensions/Responsive/responsive.bootstrap4
//= require datatables/extensions/FixedColumns/fixedColumns.bootstrap4
//= require datatables/extensions/FixedColumns/dataTables.fixedColumns

function initializeDataTable(cssSelector, params){ // jshint ignore:line
  var defaultParams = {
    language: { search: '', searchPlaceholder: "Search..." },
    stateSave: true,
    stateDuration: 172800 // 2 days
  };
  var newParams = $.extend(defaultParams, params);
  $(cssSelector).DataTable(newParams);
}

function initializeRemoteDatatable(cssSelector, params) { // jshint ignore:line
  var defaultParams = {
    language: { search: '', searchPlaceholder: "Search..." },
    processing: true,
    serverSide: true,
    ajax: $(cssSelector).data('source'),
    pagingType: 'full_numbers',
    stateSave: true,
    stateDuration: 172800 // 2 days
  };
  var newParams = $.extend(defaultParams, params);

  $(cssSelector).dataTable(newParams);
}
