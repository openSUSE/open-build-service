function makeServicesDragable() { // jshint ignore:line
  $("#services").sortable( {
    placeholder: "empty_service",
    update: function(event, ui) {
      var position = -1;
      $(this).find(".service").each(function(index) {
        if ($(this).attr("id") === ui.item.attr("id")) {
          position = index;
        }
      });
      $("#services").animate({opacity: 0.2}, 500);
      $("#services").sortable('disable');
      $.ajax({
        type: 'post',
        url: $(this).data().url,
        data: { "item": ui.item.attr("id"),
          "position": position,
          "package": $(this).data().package,
          "project": $(this).data().project
        },
        success: function(data) {
          $("#services").sortable('destroy');
          $("#services_container").html(data);
          $("#services").sortable('enable');
          $("#services").animate({opacity: 1}, 500);
          makeServicesDragable();
        },
        error: function(data) {
          $("#services").text(data);
        }
      });
    }
  });
  $("#services").disableSelection();
}

var DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function addChangesEntryTemplate() { // jshint ignore:line
  var date = new Date(),
    day = date.getUTCDate().toString(),
    hours,
    minutes,
    seconds,
    templ;

  if (day.length === 1) { day = " " + day; } // Pad single character day value
  hours = date.getUTCHours();
  if (hours < 10) { hours = '0' + hours; }
  minutes = date.getUTCMinutes();
  if (minutes < 10) { minutes = '0' + minutes; }
  seconds = date.getUTCSeconds();
  if (seconds < 10) { seconds = '0' + seconds; }

  templ = "-------------------------------------------------------------------\n" +
    DAYS[date.getUTCDay()] + " " + MONTHS[date.getUTCMonth()] + " " + day + " " +
    hours + ":" + minutes + ":" + seconds + " UTC " + date.getUTCFullYear() +
    " - " + $("a.changes-link").data('packagername') +
    " <" + $("a.changes-link").data('packageremail') + ">" +"\n\n" + "- \n" + "\n";

  editors[0].setValue(templ + editors[0].getValue());
  editors[0].focus();
  editors[0].setCursor(3, 3);
}

$( document ).ready(function() {
  $('.btn-more').click(function() {
    var link = $(this);
    $('.more_info').toggle(0, function() {
      link.text($(this).is(':visible') ? 'less info' : 'more info');
    });
  });

  $('#jobhistory-table').dataTable({
    columnDefs: [
      { orderable: false, targets: [0, 8] },
      { visible: false, searchable: false, targets: [1, 5] },
      { orderData: 1, targets: 2 },
      { orderData: 5, targets: 6 },
    ],
    order: [[2, 'desc']]
  });
});
