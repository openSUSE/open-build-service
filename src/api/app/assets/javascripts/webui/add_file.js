$(document).ready(function() {
  $('#filechooser').on('change', function() {
    this.form.submit();
  });
});
