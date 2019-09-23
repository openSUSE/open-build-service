/* global initializeRemoteDatatable */

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

// eslint-disable-next-line no-unused-vars
function initializeProjectDatatable() {
  initializeRemoteDatatable(
    "#projects-datatable",
    {
      "ajax": {
        "url": $("#projects-datatable").data("source"),
        "data": function (d) {
          d.all = $("#projects-datatable").data("all");
        }
      },
      "columns": [
        { "data": "name" },
        { "data": "title" }
      ]
    }
  );
  $(".toggle-projects").click(function() { toggleProjectsDatatable(); });
}
