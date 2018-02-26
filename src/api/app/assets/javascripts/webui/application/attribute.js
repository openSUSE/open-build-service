$(document).on('change', '#attrib_attrib_type_id', function() {
  $("#first-help").hide();
  $(".attrib-type").hide();
  $('#' + $(this).val() + '-help').show();
});
