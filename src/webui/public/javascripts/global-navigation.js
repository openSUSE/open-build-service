$(document).ready(function() {

var lang = (navigator.language) ? navigator.language : navigator.userLanguage;

lang = 'en';

$.getScript('http://static.opensuse.org/themes/bento/js/global-navigation-' + lang + '.js', function() {

var html = '';

$.each(global_navigation_data, function(i,menu){
  html += '<ul class="global-navigation-menu" id="menu-' + menu.id + '">';
  $.each(menu.items, function(j,submenu){
    html += '<li><a href="' + submenu.link +'">';
    html += '<img src="http://static.opensuse.org/themes/bento/images/' + submenu.image + '.png" alt="" />';
    html += '<div>' + submenu.title + '</div>';
    html += '<div class="desc">' + submenu.desc + '</div>';
    html += '</a></li>';
  });
  html += '</ul>';
});

$('#global-navigation').after(html);

var top = $('#global-navigation').height()-12;
if ($.browser.webkit) top += 1;
var left = $('#item-downloads').offset().left-15;
$('#menu-downloads').offset({left:left,top:top});
var left = $('#item-support').offset().left-16;
$('#menu-support').offset({left:left,top:top});
var left = $('#item-community').offset().left-16;
$('#menu-community').offset({left:left,top:top});
var left = $('#item-development').offset().left-16;
$('#menu-development').offset({left:left,top:top});

$('#item-downloads').click(function(){
  $('#global-navigation li.selected').removeClass('selected');
  $(this).addClass('selected');
  $('#menu-downloads').fadeIn();
  $('#menu-support').fadeOut();
  $('#menu-community').fadeOut();
  $('#menu-development').fadeOut();
  return false;
});
$('#item-support').click(function(){
  $('#global-navigation li.selected').removeClass('selected');
  $(this).addClass('selected');
  $('#menu-downloads').fadeOut();
  $('#menu-support').fadeIn();
  $('#menu-community').fadeOut();
  $('#menu-development').fadeOut();
  return false;
});
$('#item-community').click(function(){
  $('#global-navigation li.selected').removeClass('selected');
  $(this).addClass('selected');
  $('#menu-downloads').fadeOut();
  $('#menu-support').fadeOut();
  $('#menu-community').fadeIn();
  $('#menu-development').fadeOut();
  return false;
});
$('#item-development').click(function(){
  $('#global-navigation li.selected').removeClass('selected');
  $(this).addClass('selected');
  $('#menu-downloads').fadeOut();
  $('#menu-support').fadeOut();
  $('#menu-community').fadeOut();
  $('#menu-development').fadeIn();
  return false;
});

$('.global-navigation-menu').mouseleave(function(){
  $('#global-navigation li.selected').removeClass('selected');
  $(this).fadeOut();
});

});

});
