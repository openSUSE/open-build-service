$(document).ready(function() {

var top = $('#global-navigation').height()-12;
if ($.browser.webkit) top += 1;
var left = $('#global-favorites').offset().left-16;
$('#menu-favorites').offset({left:left,top:top});
$('#menu-favorites').hide();

$('#global-favorites').click(function(){
  //alert ($('#global-navigation li.selected').name);
  $('#global-navigation li.selected').removeClass('selected');
  $(this).addClass('selected');
  $("ul[id^=menu-]").each(function() { $(this).fadeOut(); } );
  $('#menu-favorites').fadeIn();
  return false;
});

});
