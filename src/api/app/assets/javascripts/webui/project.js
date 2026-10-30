/* global initializeRemoteDatatable */
/* exported initializeProjectDatatable, initializeProjectDatatableLabelBeta */

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

function toggleVendorsProjectsDatatable() {
  var vendors = $("#projects-datatable").data("vendors");
  var $toggleText = $("#toggle-vendor-text");
  var $text = $toggleText.text();

  if (vendors) {
    $toggleText.text($text.replace("Exclude", "Include"));
  } else {
    $toggleText.text($text.replace("Include", "Exclude"));
  }

  $("#toggle-vendor-icon").toggleClass("fa-toggle-on fa-toggle-off");
  $("#projects-datatable").data("vendors", !vendors);
  $("#projects-datatable").DataTable().draw();
}

function initializeProjectDatatable() {
  initializeRemoteDatatable(
    "#projects-datatable",
    {
      "ajax": {
        "url": $("#projects-datatable").data("source"),
        "data": function (d) {
          d.all = $("#projects-datatable").data("all");
          d.vendors = $("#projects-datatable").data("vendors");
        }
      }, "responsive" : true,
      "columns": [
        { "data": "name" },
        { "data": "title" }
      ], "dom": "ftpi"
    }
  );
  $(".toggle-projects").click(function() { toggleProjectsDatatable(); });
  $(".toggle-vendors-projects").click(function() { toggleVendorsProjectsDatatable(); });
}

function initializeProjectDatatableLabelBeta() {
  initializeRemoteDatatable(
    "#projects-datatable",
    {
      "ajax": {
        "url": $("#projects-datatable").data("source"),
        "data": function (d) {
          d.all = $("#projects-datatable").data("all");
          d.vendors = $("#projects-datatable").data("vendors");
        }
      }, "responsive" : true,
      "columns": [
        { "data": "name" },
        { "data": "labels", "name": "labels", "orderable": false},
        { "data": "title" }
      ], "dom": "ftpi"
    }
  );
  $(".toggle-projects").click(function() { toggleProjectsDatatable(); });
  $(".toggle-vendors-projects").click(function() { toggleVendorsProjectsDatatable(); });
}
