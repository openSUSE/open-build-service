//= require datatables/jquery.dataTables
//= require datatables/dataTables.bootstrap5
//= require datatables/extensions/Responsive/dataTables.responsive
//= require datatables/extensions/Responsive/responsive.bootstrap5
//= require datatables/extensions/FixedColumns/fixedColumns.bootstrap5
//= require datatables/extensions/FixedColumns/dataTables.fixedColumns

var DEFAULT_DT_PARAMS = {
  language: { 
    search: '', searchPlaceholder: "Search...",
    zeroRecords: "Nothing found",
    infoEmpty: "No records available",
    info: "page _PAGE_ of _PAGES_ (_TOTAL_ records)",
    infoFiltered: ""
  },
  responsive: true,
  pageLength: 25,
  stateSave: true,
  pagingType: 'full',
  stateDuration: 0, // forever
  // Save the state of the columns sort and the number of shown entries per page
  stateSaveParams: function (_settings, data) {
    // Do not keep the selected page in the datatable state
    data.start = 0;
    // Do not save the state of the search string
    data.search.search = "";
  }
};

function initializeDataTable(cssSelector, params){ // jshint ignore:line
  var newParams = $.extend({}, DEFAULT_DT_PARAMS, params);
  $(cssSelector).DataTable(newParams);
}

function initializeRemoteDatatable(cssSelector, params) { // jshint ignore:line
  var defaultRemoteParams = {
    processing: true,
    serverSide: true,
    ajax: $(cssSelector).data('source')
  };
  var newParams = $.extend(defaultRemoteParams, DEFAULT_DT_PARAMS, params);

  $(cssSelector).dataTable(newParams);
}
