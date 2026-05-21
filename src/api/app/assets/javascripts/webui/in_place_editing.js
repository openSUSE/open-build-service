/* exported setFormValidation, resetFormValidation, scrollToInPlace */

function setFormValidation(element, messages) {
  element.addClass('is-invalid');
  element.after("<div class='invalid-feedback'>"+ messages + "</div>");
}

function resetFormValidation() {
  $('.in-place-editing form .is-invalid').each(function(){
    $(this).toggleClass('is-invalid');
    $(this).siblings('.invalid-feedback').remove();
  });
}

function scrollToInPlace() {
  $('html, body').animate({
    scrollTop: $('.in-place-editing').offset().top - 73 // header height + 16px
  }, 500);
}
