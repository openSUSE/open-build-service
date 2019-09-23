//= require datatables/jquery.dataTables
//= require datatables/dataTables.bootstrap4
//= require datatables/extensions/Responsive/dataTables.responsive
//= require datatables/extensions/Responsive/responsive.bootstrap4
//= require datatables/extensions/FixedColumns/fixedColumns.bootstrap4
//= require datatables/extensions/FixedColumns/dataTables.fixedColumns

var DEFAULT_DT_PARAMS = {
  language: { search: '', searchPlaceholder: "Search..." },
  pageLength: 25,
  stateSave: true,
  stateDuration: 0 // forever
};

// eslint-disable-next-line no-unused-vars
function initializeDataTable(cssSelector, params){
  var newParams = $.extend({}, DEFAULT_DT_PARAMS, params);
  $(cssSelector).DataTable(newParams);
}

// eslint-disable-next-line no-unused-vars
function initializeRemoteDatatable(cssSelector, params) {
  var defaultRemoteParams = {
    processing: true,
    serverSide: true,
    ajax: $(cssSelector).data('source')
  };
  var newParams = $.extend(defaultRemoteParams, DEFAULT_DT_PARAMS, params);

  $(cssSelector).dataTable(newParams);
}
