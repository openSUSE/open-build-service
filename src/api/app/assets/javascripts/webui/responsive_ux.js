$(function () {
  $('[data-toggle="offcanvas"]').on('click', function () {
    $('a[data-toggle="offcanvas"]').toggleClass('active');
    $('.offcanvas-collapse').toggleClass('open');
    $('.watchlist-collapse').removeClass('open');
    $('.actions-collapse').removeClass('open');
    $('a[data-toggle="watchlist"]').removeClass('active');
    $('a[data-toggle="actions"]').removeClass('active');
  });

  $('[data-toggle="watchlist"]').on('click', function () {
    $('a[data-toggle="watchlist"]').toggleClass('active');
    $('.watchlist-collapse').toggleClass('open');
    $('.offcanvas-collapse').removeClass('open');
    $('.actions-collapse').removeClass('open');
    $('a[data-toggle="offcanvas"]').removeClass('active');
    $('a[data-toggle="actions"]').removeClass('active');
  });

  $('[data-toggle="actions"]').on('click', function () {
    $('a[data-toggle="actions"]').toggleClass('active');
    $('.actions-collapse').toggleClass('open');
    $('.offcanvas-collapse').removeClass('open');
    $('.watchlist-collapse').removeClass('open');
    $('a[data-toggle="offcanvas"]').removeClass('active');
    $('a[data-toggle="watchlist"]').removeClass('active');
  });

  $('.access-modal').on('show.bs.modal', function () {
    $('.access-modal').modal('hide');
  });

  $('.access-modal').on('shown.bs.modal', function () {
    $('#login').focus();
    $('#username').focus();
  });
});

/* bootstrap's tabs javascript doesn't remove the active class
   when tabs are implemented without the usage of ul and li */
function toggleTabs(tabLinkContainerId) { // jshint ignore:line
  $('#' + tabLinkContainerId + ' a').on('click', function (e) {
    e.preventDefault();
    $(this).tab('show');
    var currentTabLink = $(this);
    $('#' + tabLinkContainerId + ' a').removeClass('active');
    currentTabLink.addClass('active');
  });
}

function setFormValidation(element, messages) { // jshint ignore:line
  element.addClass('is-invalid');
  element.after("<div class='invalid-feedback'>" + messages + "</div>");
}

function resetFormValidation() { // jshint ignore:line
  $('.in-place-editing form .is-invalid').each(function () {
    $(this).toggleClass('is-invalid');
    $(this).siblings('.invalid-feedback').remove();
  });
}

function scrollToInPlace() { // jshint ignore:line
  $('html, body').animate({
    scrollTop: $('.in-place-editing').offset().top - 73 // header height + 16px
  }, 500);
}
