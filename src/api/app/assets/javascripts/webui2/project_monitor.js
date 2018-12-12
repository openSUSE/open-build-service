function setupPopover() {
  $('[data-toggle="popover"]').popover({ trigger: 'hover click' });
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
    }
  });

  $('#project-monitor-table').on('draw.dt', function () {
    setupPopover();
  });

  setupPopover();

  $('.monitor-no-filter-link').on('click', function () {
    $(this).siblings().children('input:checked').prop('checked', false);
  });
}