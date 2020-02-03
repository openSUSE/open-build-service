$(function () {
  $('[data-toggle="offcanvas"]').on('click', function () {
    $('.offcanvas-collapse').toggleClass('open');
    $('.navbar-toggler').toggleClass('open');
    $('.watchlist-collapse').removeClass('open');
  });

  $('[data-toggle="watchlist"]').on('click', function () {
    $('.watchlist-collapse').toggleClass('open');
    $('.navbar-toggler').removeClass('open');
    $('.offcanvas-collapse').removeClass('open');
  });

  $('[data-toggle="log-in"]').on('click', function () {
    $('#login-form-canvas').toggleClass('open');
    $('.navbar-toggler').removeClass('open');
    $('.login-form').removeClass('d-none');
    $('.signup-form').addClass('d-none');
  });

  $('[data-toggle="sign-up"]').on('click', function () {
    $('#login-form-canvas').toggleClass('open');
    $('.navbar-toggler').removeClass('open');
    $('.login-form').addClass('d-none');
    $('.signup-form').removeClass('d-none');
  });

  $('[data-toggle="toggle-unlogged-form"]').on('click', function () {
    $('.login-form').toggleClass('d-none');
    $('.signup-form').toggleClass('d-none');
  });
});
