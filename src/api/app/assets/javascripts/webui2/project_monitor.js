function hideRepositoryColumns() {
  var table = $('#project-monitor-table').DataTable();

  var repositories = [];
  $('#project-monitor-repositories-dropdown input:checked').each(function () {
    repositories.push($(this).val().trim());
  });

  if (repositories.length === 0) {
    return;
  }

  var toShowColumns = [];
  var offSet = 0;
  $('#project-monitor-table thead tr:eq(0) th').each(function () {
    var column = $(this);
    var colSpan = column.prop('colspan');
    if (repositories.includes(column.text().trim())) {
      var range = [];
      for (var i = offSet; i < offSet + colSpan; i++) {
        range.push(i);
      }
      toShowColumns = toShowColumns.concat(range);
    }
    offSet += colSpan;
  });

  table.columns().every(function () {
    var index = this.index();
    if (index === 0) return;
    this.visible(toShowColumns.includes(index));
  });
}

function hideArchitectureColumns() {
  var table = $('#project-monitor-table').DataTable();

  var architectures = [];
  $('#project-monitor-architectures-dropdown input:checked').each(function () {
    architectures.push($(this).val());
  });

  if (architectures.length === 0) {
    return;
  }

  table.columns().every(function () {
    if (this.index() === 0) return;
    if (!this.visible()) return;

    var title = $(this.header()).text().trim();
    this.visible(architectures.includes(title));
  });
}

function updateStatusSearch() {
  var table = $('#project-monitor-table').DataTable();
  var searchInput = $('#project-monitor_filter input');

  var terms = [];
  $('#project-monitor-status-dropdown input:checked').each(function () {
    terms.push($(this).val());
  });

  var searchTerm = terms.join("|");
  searchInput.val(searchTerm);
  table.search(searchTerm).draw();
}

function updateMonitorFilters() {
  updateStatusSearch();
  var table = $('#project-monitor-table').DataTable();
  table.columns().visible(true);
  hideRepositoryColumns();
  hideArchitectureColumns();
}

function setupProjectMonitor() { // jshint ignore:line
  initializeDataTable('#project-monitor-table', { // jshint ignore:line
    scrollX: true,
    scrollY: "50vh",
    fixedColumns: true,
    pageLength: 50,
    search: {
      regex: true,
      smart: false,
    }
  });

  $('[data-toggle="popover"]').popover({ trigger: 'hover click' });

  $('#project-monitor-status-dropdown input:checkbox').on('change', function () {
    updateStatusSearch();
  });

  $('.monitor-no-filter-link').on('click', function () {
    $(this).siblings().children('input:checked').prop('checked', false);
    updateMonitorFilters();

  });

  $('#project-monitor-architectures-dropdown input:checkbox, #project-monitor-repositories-dropdown input:checkbox').on('change', function () {
    updateMonitorFilters();
  });
}