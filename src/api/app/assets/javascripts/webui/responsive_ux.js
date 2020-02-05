$(function () {
  $('[data-toggle="offcanvas"]').on('click', function () {
    $('a[data-toggle="offcanvas"]').toggleClass('active');
    $('.offcanvas-collapse').toggleClass('open');
    $('.watchlist-collapse').removeClass('open');
    $('a[data-toggle="watchlist"]').removeClass('active');
    $('.contextual-collapse').removeClass('open');
  });

  $('[data-toggle="watchlist"]').on('click', function () {
    $('a[data-toggle="watchlist"]').toggleClass('active');
    $('.watchlist-collapse').toggleClass('open');
    $('.offcanvas-collapse').removeClass('open');
    $('a[data-toggle="offcanvas"]').removeClass('active');
    $('.contextual-collapse').removeClass('open');
  });

  $('.access-modal').on('show.bs.modal', function () {
    $('.access-modal').modal('hide');
  });

  $('.access-modal').on('shown.bs.modal', function () {
    $('#login').focus();
    $('#username').focus();
  });

  $('[data-toggle="contextual"]').on('click', function () {
    $('.contextual-collapse').toggleClass('open');
    $('.watchlist-collapse').removeClass('open');
    $('.navbar-toggler').removeClass('open');
    $('.offcanvas-collapse').removeClass('open');
  });
});
