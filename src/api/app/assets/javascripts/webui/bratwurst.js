// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap

$(function() {
  // add a hash to the URL when the user clicks on a tab
  $('a[data-toggle="tab"]').on('click', function(e) {
    history.pushState(null, null, $(this).attr('href'));
  });

  // navigate to a tab when the history changes
  var activeTab = $('[href=' + location.hash + ']');
  window.addEventListener('popstate', function(e) {
    if (activeTab.length) {
      activeTab.tab('show');
    } else {
      $('.nav-tabs a[href=#<%= j @today %>]').tab('show');
    }
  });
});

$(function() {
  var hash = window.location.hash;
  if (hash)
    $('ul.nav a[href="' + hash + '"]').tab('show');
});
