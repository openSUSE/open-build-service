//= require datatables/jquery.dataTables
//= require datatables/dataTables.bootstrap4
//= require datatables/extensions/Responsive/dataTables.responsive
//= require datatables/extensions/Responsive/responsive.bootstrap4
//= require datatables/extensions/FixedColumns/fixedColumns.bootstrap4
//= require datatables/extensions/FixedColumns/dataTables.fixedColumns

function initializeDataTable(cssSelector, params){ // jshint ignore:line
    var defaultParams = {
        language: { search: '', searchPlaceholder: "Search..." },
    };
    var newParams = $.extend(defaultParams, params);
    $(cssSelector).DataTable(newParams);
}
