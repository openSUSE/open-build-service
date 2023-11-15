// JavaScript code for the new view under request_show_redesign

$(document).ready(function() {
  $('#request-actions').on('shown.bs.dropdown', function () {
    // Scrolls towards the current request action
    var currentAction = $('a.dropdown-item.active');
    currentAction[0].scrollIntoView({behavior: "smooth", block: "center"});
  });
});
