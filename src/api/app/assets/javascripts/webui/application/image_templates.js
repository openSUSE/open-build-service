// Disable button if appliance name field is empty
$(function() {
  $('#target_package').on("input", function(e){
    $(".create_appliance").attr('disabled', (this.value === ""));
  });
});

// Change the package and project to the selected one before submiting the form to create an appliance
$(function() {
  $(".create_appliance").on("click", function(e){
    e.preventDefault();
    var checked_element = $("input[name=image]:checked");
    var url = '/package/branch/' + checked_element.attr('data-project') + '/' + checked_element.attr('data-package');
    $('#appliance_form').attr('action', url).submit();
  });
});

// Change the appliance name when selecting a new template
$(function() {
  $(".image_template").on("click", function(e){
    $('#target_package').val(this.getAttribute('data-package'));
  });
});