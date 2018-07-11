function renderPackagesTable(wrapper, packages, length) { // jshint ignore:line
  length = (typeof length === "undefined") ? 25 : length;
  var packageurl = $("#" + wrapper).data("url");
  $("#" + wrapper).html('<table cellpadding="0" cellspacing="0" border="0" class="table table-striped table-responsive table-sm" id="' + wrapper + '_table"></table>');
  $("#" + wrapper + "_table").dataTable({
    "data": packages,
    "ordering": true,
    "paging": packages.length > 12,
    "autoWidth": false,
    "pagingType": "simple",
    "columns": [
      {
        "title": "Name",
        "width": "100%",
        "render": function (obj) {
          var url = packageurl.replace(/REPLACEIT/, obj);
          return '<a href="' + url + '">' + obj + '</a>';
        }
      },
      {
        "title": "Changed",
        "width": "50%",
        "render": function (obj) {
          var fromnow = moment.unix(parseInt(obj)).fromNow();
          if (fromnow.match(/^in\s/)) {
            fromnow = "now"; // in case server time is ahead of client
          }
          return '<span class="d-none">' + obj + '</span>' + fromnow;
        }
      }
    ],
    "pageLength": length,
    "stateSave": true
  });
}

function renderProjectsTable(length) { // jshint ignore:line
  length = (typeof length === "undefined") ? 25 : length;
  var projects = mainProjects;
  if (!$('#excludefilter').is(":checked"))
    projects = projects.concat(exclProjects);
  var projecturl = $("#projects-table-wrapper").data("url");
  $("#projects-table-wrapper").html('<table cellpadding="0" cellspacing="0" border="0" class="table table-striped table-responsive table-sm" id="projects_table"></table>');
  $("#projects_table").dataTable({
    "data": projects,
    "paging": true,
    "pagingType": "simple",
    "columns": [
      {
        "title": "Name",
        "render": function (obj, type, dataRow) {
          var url = projecturl.replace(/REPLACEIT/, dataRow[0]);
          return '<a href="' + url + '">' + dataRow[0] + '</a>';
        }
      },
      {
        "title": "Title",
        "width": "100%"
      }
    ],
    "pageLength": length,
    "stateSave": true
  });
}

function renderPackagesProjectsTable(options) { // jshint ignore:line
  var length = options.length || 25;
  var name = options.name || "packages_projects_wrapper";

  var packageurl = $("#" + name).data("url");
  $("#" + name).html("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" class=\"table table-striped table-responsive table-sm\" id=\"" + name + '_table' + "\"></table>");
  $("#" + name + "_table").dataTable(
    {
      "data": options.packages,
      "paging": options.packages.length > 12,
      "pagingType": "simple",
      "columns": [
        {
          "title": "Package",
          "render": function (obj, type, dataRow) {
            var url1 = packageurl.replace(/REPLACEPKG/, dataRow[0]);
            var url = url1.replace(/REPLACEPRJ/, dataRow[1]);
            return '<a href="' + url + '">' + dataRow[0] + '</a>';
          }
        },
        {
          "columns.title": "Project"
        }
      ],
      "pageLength": length,
      "stateSave": true
    });
}


function autocompleteRepositories(projectName) {
  if (projectName === "")
    return;
  $('#loader-repo').show();
  $('#add_repository_button').prop('disabled', true);
  $('#target_repo').prop('disabled', true);
  $('#repo_name').prop('disabled', true);
  $.ajax({
    url: $('#target_repo').data('ajaxurl'),
    data: {project: projectName},
    success: function (data) {
      $('#target_repo').html('');
      // suggest a name:
      $('#repo_name').attr('value', projectName.replace(/:/g, '_') + '_' + data[0]);
      var foundoptions = false;
      $.each(data, function (idx, val) {
        $('#target_repo').append(new Option(val));
        $('#target_repo').prop('disabled', false);
        $('#repo_name').prop('disabled', false);
        $('#add_repository_button').prop('disabled', false);
        foundoptions = true;
      });
      if (!foundoptions)
        $('#target_repo').append(new Option('No repos found'));
    },
    complete: function() {
      $('#loader-repo').hide();
    }
  });
}

function repositoriesSetupAutocomplete() { // jshint ignore:line
  $("#target_project").autocomplete({
    source: $('#target_project').data('ajaxurl'),
    minLength: 2,
    select: function(event, ui) {
      autocompleteRepositories(ui.item.value);
    },
    change: function() {
      autocompleteRepositories($('#target_project').attr('value'));
    },
    search: function() {
      $(this).addClass('loading-spinner');
    },
    response: function() {
      $(this).removeClass('loading-spinner');
    }
  });

  $("#target_project").change(function () {
    autocompleteRepositories($('#target_project').attr('value'));
  });

  $('#target_repo').select(function () {
    $('#repo_name').attr('value', $("#target_project").attr('value').replace(/:/g, '_') + '_' + $(this).val());
  });
}

function setupSubprojectsTables() { // jshint ignore:line
  $('#parentprojects-table').dataTable({
    'paging': false,
    'searching': false,
    'info': false,
    "autoWidth": false
  });
  if ($('#siblingprojects-table').length) {
    $('#siblingprojects-table').dataTable({
    'paging': false,
    'searching': false,
    'info': false,
    "autoWidth": false,
    "columnDefs": [
      { "width": "100%", "targets": 0 }
	]
    });
  }
  $('#subprojects-table').dataTable({
    'paging': false,
    'searching': false,
    'info': false,
    "autoWidth": false,
    "columnDefs": [
      { "width": "100%", "targets": 0 }
    ]
  });
}
