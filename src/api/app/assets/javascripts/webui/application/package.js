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
    " - " + $("a.changes-link").data('email') + "\n\n" + "- \n" + "\n";

  editors[0].setValue(templ + editors[0].getValue());
  editors[0].focus();
  editors[0].setCursor(3, 3);
}


function autoscroll() {
  var lw = $('#log_space_wrapper');
  if (!lw.data("autorefresh")) { return; }
  var lastScroll = lw.data("lastScroll");
  // just return in case the user scrolled up
  if (lastScroll > window.pageYOffset) { return; }
  // stop refresh if the user scrolled down
  if (lastScroll < window.pageYOffset && lastScroll) { stop_refresh(); return; }
  var targetOffset = $('#footer').offset().top - window.innerHeight;
  window.scrollTo( 0, targetOffset );
  lw.data("lastScroll", window.pageYOffset);
}

function build_finished() { // jshint ignore:line
  stop_refresh();
  $('#status').html('Build finished');
}

function start_refresh() {
  var lw = $('#log_space_wrapper');
  lw.data("autorefresh", 1);
  lw.data("lastScroll", 0);
  refresh(lw.data("offset"), 0);
  $('.start_refresh').hide();
  $('.stop_refresh').show();
  return false;
}

function remove_ajaxreq() { // jshint ignore:line
  var lw = $('#log_space_wrapper');
  lw.data("ajaxreq", 0);
}

function stop_refresh() {
  var lw = $('#log_space_wrapper');
  lw.data("autorefresh", 0);
  if (lw.data("ajaxreq") !== 0)
    lw.data("ajaxreq").abort();
  lw.data("ajaxreq", 0);
  $('.stop_refresh').hide();
  $('.start_refresh').show();
  return false;
}

function refresh(newoffset, initial) {
  autoscroll();
  var lw = $('#log_space_wrapper');
  lw.data("offset", newoffset);
  if (lw.data("autorefresh")) {
    var options = { type: 'GET',
      data: null,
      error: 'stop_refresh()',
      completed: 'remove_ajaxreq()',
      cache: false };

    var baseurl = lw.data('url');
    options.url = baseurl + '&offset=' + lw.data("offset") + ';&' + 'initial=' + initial;
    lw.data("ajaxreq", $.ajax(options));
  }
}

function show_abort() { // jshint ignore:line
  $(".link_abort_build").show();
  $(".link_trigger_rebuild").hide();
}

function hide_abort() { // jshint ignore:line
  $(".link_abort_build").hide();
  $(".link_trigger_rebuild").show();
}

function live_build_log_ready() { // jshint ignore:line, unused:true
  var lw = $('#log_space_wrapper');
  lw.data("autorefresh", 1);
  lw.data("lastScroll", 0);

  refresh(lw.data("offset"), 1);
  $('.start_refresh').click(start_refresh);
  $('.stop_refresh').click(stop_refresh);
}

$( document ).ready(function() {
  $('.btn-more').click(function() {
    var link = $(this);
    $('.more_info').toggle(0, function() {
      link_text = $(this).is(':visible') ? 'less info' : 'more info';
      link.text(link_text);
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
