function setupImageTemplates() { // jshint ignore:line
  $(".image_template").on("click", function(){
    $('#target_package').val(this.getAttribute('data-package'));
    $('#linked_package').val(this.getAttribute('data-package'));
    $('#linked_project').val(this.getAttribute('data-project'));
  });
}
