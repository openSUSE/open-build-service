$(window).scroll(function() {
  if (this.scrollY > 100) {
    $('.flash-and-announcement').addClass('sticking');
  } else {
    $('.flash-and-announcement').removeClass('sticking');
  }
});
