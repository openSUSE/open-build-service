function setupProjectMonitor() { // jshint ignore:line
  initializeDataTable('#project-monitor-table', { // jshint ignore:line
    scrollX: true,
    scrollY: "50vh",
    fixedColumns: true,
    pageLength: 50,
    lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "All"]],
    search: {
      regex: true,
      smart: false,
    }
  });

  $('[data-toggle="popover"]').popover({ trigger: 'hover click' });

  $('.monitor-no-filter-link').on('click', function () {
    $(this).siblings().children('input:checked').prop('checked', false);
  });
}