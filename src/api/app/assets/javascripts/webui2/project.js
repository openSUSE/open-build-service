function projectsDatatable(tableSelector, params) {
  var defaultParams = {
    "processing": true,
    "serverSide": true,
    "ajax": $(tableSelector).data("source"),
    "pagingType": "full_numbers",
    "columns": [
      {"data": "name"},
      {"data": "title"}
    ]
    // pagingType is optional, if you want full pagination controls.
    // Check dataTables documentation to learn more about
    // available options.
  };
  var newParams = $.extend(defaultParams, params);

  $(tableSelector).dataTable(newParams);
}

function toggleProjectsDatatable() {
  var all = $("#projects-datatable").data("all");
  var $toggleText = $("#toggle-text");
  var $text = $toggleText.text();

  if (all) {
    $toggleText.text($text.replace("Exclude", "Include"));
  } else {
    $toggleText.text($text.replace("Include", "Exclude"));
  }

  $("#toggle-icon").toggleClass("fa-toggle-on fa-toggle-off");
  $("#projects-datatable").data("all", !all);
  $("#projects-datatable").DataTable().draw();
}

function initializeProjectDatatable() { // jshint ignore:line
  projectsDatatable(
    "#projects-datatable",
    {
      "ajax": {
        "url": $("#projects-datatable").data("source"),
        "data": function (d) {
          d.all = $("#projects-datatable").data("all");
        }
      }
    }
  );
  $(".toggle-projects").click(function() { toggleProjectsDatatable(); });
}
