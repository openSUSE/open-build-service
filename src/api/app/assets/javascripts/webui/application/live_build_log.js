function live_build_log_ready() { // jshint ignore:line, unused:true
  var lw = $('#log_space_wrapper');
  lw.data("autorefresh", 1);
  lw.data("lastScroll", 0);

  refresh(lw.data("offset"), 1);
  $('.start_refresh').click(startRefresh);
  $('.stop_refresh').click(stopRefresh);
}

function build_finished() { // jshint ignore:line
  stopRefresh();
  $('#status').html('Build finished');
}

function startRefresh() {
  var lw = $('#log_space_wrapper');
  lw.data("autorefresh", 1);
  lw.data("lastScroll", 0);
  refresh(lw.data("offset"), 0);
  $('.start_refresh').hide();
  $('.stop_refresh').show();
  return false;
}

function stopRefresh() {
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
      error: 'stopRefresh()',
      completed: 'remove_ajaxreq()',
      cache: false };

    var baseurl = lw.data('url');
    options.url = baseurl + '&offset=' + lw.data("offset") + ';&' + 'initial=' + initial;
    lw.data("ajaxreq", $.ajax(options));
  }
}

function autoscroll() {
  var lw = $('#log_space_wrapper');
  if (!lw.data("autorefresh")) { return; }
  var lastScroll = lw.data("lastScroll");
  // just return in case the user scrolled up
  if (lastScroll > window.pageYOffset) { return; }
  // stop refresh if the user scrolled down
  if (lastScroll < window.pageYOffset && lastScroll) { stopRefresh(); return; }
  var targetOffset = $('#footer').offset().top - window.innerHeight;
  window.scrollTo( 0, targetOffset );
  lw.data("lastScroll", window.pageYOffset);
}

function remove_ajaxreq() { // jshint ignore:line
  var lw = $('#log_space_wrapper');
  lw.data("ajaxreq", 0);
}

function show_abort() { // jshint ignore:line
  $(".link_abort_build").show();
  $(".link_trigger_rebuild").hide();
}

function hide_abort() { // jshint ignore:line
  $(".link_abort_build").hide();
  $(".link_trigger_rebuild").show();
}
