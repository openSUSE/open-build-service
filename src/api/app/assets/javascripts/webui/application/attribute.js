$(function() {
  $('#attrib_attrib_type_id').on(
    { "change": function() {
        $("#first-help").hide();
        $(".attrib-type").hide();
        $('#' + $(this).val() + '-help').show();
      }
    });
  });