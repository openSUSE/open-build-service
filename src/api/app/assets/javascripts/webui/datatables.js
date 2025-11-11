/* exported initializeDataTable, initializeRemoteDatatable, labelFiltering */

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

function initializeDataTable(cssSelector, params){
  var newParams = $.extend({}, DEFAULT_DT_PARAMS, params);
  $(cssSelector).DataTable(newParams);
}

function initializeRemoteDatatable(cssSelector, params) {
  var defaultRemoteParams = {
    processing: true,
    serverSide: true,
    ajax: $(cssSelector).data('source')
  };
  var newParams = $.extend(defaultRemoteParams, DEFAULT_DT_PARAMS, params);

  $(cssSelector).dataTable(newParams);
}

function labelFiltering() {
  var table = $('#packages-table').DataTable();
  var labelColumn = table.column('labels:name');
  var clear = $('#label-clear');
  $('.obs-dataTable').parent().on('click', '.label-filter', function(e) {
    e.preventDefault();
    e.stopPropagation();
    var label = e.target.parentElement.dataset.label;
    clear.html('');
    clear.data('label', label);

    if (label === labelColumn.search())
      labelColumn.search('').draw();
    else
      labelColumn.search(label).draw();

    if (labelColumn.search() !== '')
      clear.html('Clear label filter');
  });
  if (labelColumn.search() !== '')
    labelColumn.search('').draw();
}
