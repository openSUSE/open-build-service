$(function() {
  $(".image_template").on("click", function(e){
    $('#target_package').val(this.getAttribute('data-package'));
    $('#linked_package').val(this.getAttribute('data-package'));
    $('#linked_project').val(this.getAttribute('data-project'));
  });
});