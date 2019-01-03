function renderProjectsTable(length) { // jshint ignore:line
  length = length || 25;
  var projects = mainProjects;
  if (!$('#excludefilter').is(":checked"))
    projects = projects.concat(exclProjects);
  var projecturl = $("#projects-table-wrapper").data("url");
  $("#projects-table").DataTable({
    "data": projects,
    "columns": [
      {
        "title": "Name",
        "className": "text-word-break-all w-75",
        "render": function (obj, type, dataRow) {
          var url = projecturl.replace(/REPLACEIT/, dataRow[0]);
          return '<a href="' + url + '">' + dataRow[0] + '</a>';
        }
      },
      {
        "title": "Title",
        "className": "text-nowrap w-25"
      }
    ],
    "pageLength": length,
    "stateSave": true,
    "language": { "search": '', "searchPlaceholder": "Search..." }
  });
}
