$(document).ready(function() {
  // TODO: Edge case - When a user is already on the page and does a refresh, the description flickers as it appears. Find a way to fix this...
  $('#attribute_type-description-' + $('#attrib_attrib_type_id option:selected').val()).removeClass('d-none');

  $('#attrib_attrib_type_id').change(function() {
    $("[id^='attribute_type-description-']:visible").addClass('d-none');
    $('#attribute_type-description-' + $(this).val()).removeClass('d-none');
  });
});
