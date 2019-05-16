function setupImageTemplates() { // jshint ignore:line
  $(".image_template").on("click", function(){
    $('.image-template-box').removeClass('active');
    $(this).parents('.image-template-box').addClass('active');
    $('#target_package').val(this.getAttribute('data-package'));
    $('#linked_package').val(this.getAttribute('data-package'));
    $('#linked_project').val(this.getAttribute('data-project'));
  });

}
