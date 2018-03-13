var LiveLog = function(wrapperId, startButton, stopButton, status, finished) {
  this.wrapper = $(wrapperId);
  this.startButton = $(startButton);
  this.stopButton = $(stopButton);
  this.status = $(status);
  this.initial = true;
  this.lastScroll = 0;
  this.ajaxRequest = 0;
  this.offset = 0;
  this.finished = finished;
};

$.extend(LiveLog.prototype, {
  initialize: function() {
    this.startButton.click($.proxy(this.start, this));
    this.stopButton.click($.proxy(this.stop, this));
    this.start();
    this.initial = false;
    return this;
  },

  start: function() {
    if (!this.finished) {
      this.autoRefresh = true;
      this.lastScroll = 0;
      this.loadContent();
      this.startButton.hide();
      this.stopButton.show();
    }
    return false;
  },

  stop: function() {
    this.autoRefresh = false;
    this.stopAjaxRequest();
    this.stopButton.hide();
    this.startButton.show();
    return false;
  },

  loadContent: function() {
    if (this.autoRefresh) {
      var url = this.wrapper.data('url') + '&offset=' + this.offset + ';&' + 'initial=' + (this.initial ? '1' : '0');
      this.ajaxRequest = $.ajax({
        type: 'GET',
        url: url,
        data: null,
        error: this.stop,
        cache: false
      });
    }
  },

  autoScroll: function() {
    // just return in case the user scrolled up
    if (this.lastScroll > window.pageYOffset) { return; }
    // stop loadContent if the user scrolled down
    if (this.lastScroll < window.pageYOffset && this.lastScroll) { this.stop(); return; }
    var targetOffset = $('#footer').offset().top - window.innerHeight;
    window.scrollTo(0, targetOffset);
    this.lastScroll = window.pageYOffset;
  },

  finish: function() { // jshint ignore:line
    this.finished = true;
    this.stop();
    this.status.html('Build finished');
    this.hideAbort();
  },

  stopAjaxRequest: function() { // jshint ignore:line
    if (this.ajaxRequest !== 0)
      this.ajaxRequest.abort();
    this.ajaxRequest = 0;
  },

  showAbort: function() { // jshint ignore:line
    $(".link_abort_build").show();
    $(".link_trigger_rebuild").hide();
  },

  hideAbort: function() { // jshint ignore:line
    $(".link_abort_build").hide();
    $(".link_trigger_rebuild").show();
  }
});
