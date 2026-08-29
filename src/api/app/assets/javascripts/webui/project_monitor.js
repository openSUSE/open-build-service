/* global initializeDataTable */
/* exported setupProjectMonitor */

function setAllLinks(event) {
  $(this).closest('.dropdown-menu').find('input').prop('checked', event.data.checked);
}

function statusCell(meta, statusHash, tableInfo, projectName, packageName) {
  var info = tableInfo[meta.col - 1];
  var repository = info[0];
  var architecture = info[1];
  var status = statusHash[repository][architecture][packageName] || {};
  var code = status.code;
  var cellContent = {};
  if (code === undefined) return null;

  var klass = 'build-state-' + code;
  var output = '<a ';
  if (['succeeded', 'failed', 'building', 'finished', 'signing'].includes(code)) {
    var url = '/package/live_build_log/' + projectName + '/' + packageName + '/' + repository + '/' + architecture;
    output += 'href="' + url + '"';
  } else {
    var id = meta.row + '-' + meta.col;
    output += 'href="javascript:void(0);" id="' + id + '"';

    if (status.details !== undefined) {
      if (code === 'scheduled') klass = 'text-warning';
      output +=
        ' data-bs-content="' +
        status.details +
        '" data-bs-placement="right" data-bs-toggle="popover"';
    }
  }
  output += ' class="' + klass + '">' + code + '</a>';

  cellContent.display = output;
  cellContent.value = code;

  return cellContent;
}

function initializeMonitorDataTable() {
  var data = $('tbody').data();
  var packageNames = data.packagenames;
  var statusHash = data.statushash;
  var tableInfo = data.tableinfo;
  var projectName = data.project;
  var scmsync = data.scmsync;

  initializeDataTable('#project-monitor-table', {
    responsive: false,
    scrollX: true,
    fixedColumns: true,
    pageLength: 50,
    lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, 'All']],
    data: packageNames,
    search: {
      regex: true,
      smart: false
    },
    columnDefs: [
      {
        width: 150,
        targets: 0,
        className: 'text-start',
        data: null,
        render: function (packageName) {
          if (scmsync !== undefined) return packageName;
          var packageNameWithoutMultibuildFlavor = packageName.replace(/:\w+$/, '');
          var url = '/package/show/' + projectName + '/' + packageNameWithoutMultibuildFlavor;
          return '<a href="' + url + '">' + packageName + '</a>';
        }
      },
      {
        targets: '_all',
        data: null,
        className: 'text-center',
        render: function (packageName, type, row, meta) {
          var cellContent = statusCell(meta, statusHash, tableInfo, projectName, packageName);
          if (cellContent === null) return null;
          if (type === 'display') return cellContent.display;
          return cellContent.value;
        }
      }
    ]
  });
}

/* 🔹 FIX: Persistent & selectable popovers */
function setupPersistentPopovers() {
  $('#project-monitor-table')
    .off('click.popover')
    .on('click.popover', '[data-bs-toggle="popover"]', function (e) {
      e.preventDefault();
      e.stopPropagation();

      var popover = bootstrap.Popover.getOrCreateInstance(this, {
        trigger: 'manual',
        html: true,
        placement: 'right'
      });

      popover.toggle();
    });

  // Prevent popover from closing when clicking inside it
  $(document).on('click', '.popover', function (e) {
    e.stopPropagation();
  });

    // Close popovers when clicking outside
    $(document).on('click', function () {
      $('.popover').each(function () {
        var trigger = $('[aria-describedby="' + this.id + '"]')[0];
        if (trigger) {
          var instance = bootstrap.Popover.getInstance(trigger);
          if (instance) {
            instance.hide();
          }
        }
      });
    });
  }
function setupProjectMonitor() {
  initializeMonitorDataTable();

  $('#table-spinner').addClass('d-none');
  $('#project-monitor .obs-dataTable').removeClass('invisible');

  $('#filter-button').on('click', function () {
    $('#table-spinner').removeClass('d-none');
  });

  // Re-init popovers after DataTable redraw
  $('#project-monitor-table').on('draw.dt', function () {
    setupPersistentPopovers();
  });

  // Init on page load
  setupPersistentPopovers();

  $('.monitor-no-filter-link').on('click', { checked: false }, setAllLinks);
  $('.monitor-filter-link').on('click', { checked: true }, setAllLinks);

  $('.dropdown-menu.keep-open').on('click', function (e) {
    e.stopPropagation();
  });

  $('.monitor-search').on('input', function (e) {
    var labels = $(this).closest('.dropdown-menu').find('.form-check-label');
    Array.from(labels).forEach((label) => {
      var element = label.closest('.dropdown-item');
      element.classList.remove('d-none');
      if (!label.innerText.includes(e.target.value)) {
        element.classList.add('d-none');
      }
    });
  });
}