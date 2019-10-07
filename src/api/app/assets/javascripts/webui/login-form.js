$(document).ready(function() {
  $('#login-form-dropdown').on('shown.bs.dropdown', function() {
    $("#username").focus();
  });
});
