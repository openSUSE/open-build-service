// responsive_ux: remove after migration to responsive_ux
$(document).ready(function() {
  $('#login-form-dropdown').on('shown.bs.dropdown', function() {
    $("#username").focus();
  });
});
