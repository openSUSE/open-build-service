function setFormValidation(element, messages) { // jshint ignore:line
  element.addClass('is-invalid');
  element.after("<div class='invalid-feedback'>"+ messages + "</div>");
}

function resetFormValidation() { // jshint ignore:line
  $('.in-place-editing form .is-invalid').each(function(){
    $(this).toggleClass('is-invalid');
    $(this).siblings('.invalid-feedback').remove();
  });
}

function scrollToInPlace() { // jshint ignore:line
  $('html, body').animate({
    scrollTop: $('.in-place-editing').offset().top - 73 // header height + 16px
  }, 500);
}
