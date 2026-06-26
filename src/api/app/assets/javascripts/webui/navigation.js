$(document).ready(function () {
    $('#toggle-sidebar-button').on('click', function () {
        toggleSidebarState();
        storeSidebarState();
        toggleTooltip();
    });

    $('#left-navigation .nav-link').tooltip({
        boundary: 'viewport',
        placement: 'right'
    });
    toggleTooltip();
});

function storeSidebarState() {
    if ($('#left-navigation-area').hasClass('collapsed')){
        document.cookie = 'sidebar_collapsed=true;path=/';
    }
    else {
        document.cookie = 'sidebar_collapsed=false;path=/';
    }
}

function toggleTooltip() {
    if ($('#left-navigation-area').hasClass('collapsed')) {
        $('#left-navigation .nav-link').tooltip('enable');
    }
    else {
        $('#left-navigation .nav-link').tooltip('disable');
    }
}

function toggleSidebarState() {
    $('#toggle-sidebar-button').find('.fas').toggleClass('fa-angle-double-left fa-angle-double-right');
    $('#left-navigation-area').toggleClass('collapsed');
    $('#content').toggleClass('expanded');
}

$(function () {
    $('[data-toggle="places"]').on('click', function () {
      $('a[data-toggle="places"]').toggleClass('active');
      $('.places-collapse').toggleClass('open');
      $('.watchlist-collapse').removeClass('open');
      $('.actions-collapse').removeClass('open');
      $('a[data-toggle="watchlist"]').removeClass('active');
      $('a[data-toggle="actions"]').removeClass('active');
    });
  
    $('[data-toggle="watchlist"]').on('click', function () {
      $('a[data-toggle="watchlist"]').toggleClass('active');
      $('.watchlist-collapse').toggleClass('open');
      $('.places-collapse').removeClass('open');
      $('.actions-collapse').removeClass('open');
      $('a[data-toggle="places"]').removeClass('active');
      $('a[data-toggle="actions"]').removeClass('active');
    });
  
    $('[data-toggle="actions"]').on('click', function () {
      $('a[data-toggle="actions"]').toggleClass('active');
      $('.actions-collapse').toggleClass('open');
      $('.places-collapse').removeClass('open');
      $('.watchlist-collapse').removeClass('open');
      $('a[data-toggle="places"]').removeClass('active');
      $('a[data-toggle="watchlist"]').removeClass('active');
    });
  
    $('.access-modal').on('show.bs.modal', function () {
      $('.access-modal').modal('hide');
    });
  
    $('.access-modal').on('shown.bs.modal', function () {
      $('#login').focus();
      $('#username').focus();
    });
  
    $('.actions-collapse .nav-item').on('click', function (){
      $('.actions-collapse').removeClass('open');
      $('a[data-toggle="actions"]').removeClass('active');
    });
  });
