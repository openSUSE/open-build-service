function setupPopover() {
  $('[data-toggle="popover"]').popover({ trigger: 'hover click' });
}

function setAllLinks(event) {
  $(this).closest('.dropdown-menu').find('input').prop('checked', event.data.checked);
}

function setupProjectMonitor() { // jshint ignore:line
  initializeDataTable('#project-monitor-table', { // jshint ignore:line
    scrollX: true,
    fixedColumns: true,
    pageLength: 50,
    lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "All"]],
    search: {
      regex: true,
      smart: false,
    },
    columnDefs: [{ width: 150, targets: 0 }]
  });

  $('#table-spinner').addClass('d-none');
  $('#project-monitor .obs-dataTable').removeClass('invisible');

  $('#filter-button').on('click', function () {
    $('#table-spinner').removeClass('d-none');
  });

  $('#project-monitor-table').on('draw.dt', function () {
    setupPopover();
  });

  setupPopover();

  $('.monitor-no-filter-link').on('click', { checked: false }, setAllLinks);

  $('.monitor-filter-link').on('click', { checked: true }, setAllLinks);

  $('.dropdown-menu.keep-open').on('click', function (e) {
    e.stopPropagation();
  });
}
