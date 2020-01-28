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
});
