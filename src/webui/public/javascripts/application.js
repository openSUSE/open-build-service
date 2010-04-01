// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

// toggle visibility of an element via the CSS "display" property
// -> does NOT reserve the needed space for the element when not displayed
function toggle_display(element_id) {
  if (document.getElementById) {
    element = document.getElementById(element_id);
    if (element.style.display == "none") {
      element.style.display = "block";
    } else {
      element.style.display = "none";
    }
  }
}

// toggle visibility of an element via the CSS "display" property
// -> does NOT reserve the needed space for the element when not displayed
function toggle_display_by_name(element_name) {
  if (document.getElementsByName) {         
	elements = document.getElementsByName(element_name); 
    for (var i = 0; i < elements.length; i++) {
    	if (elements[i].style.display == "none") {
      		elements[i].style.display = "inline";
    	} else {
      		elements[i].style.display = "none";
    	}	  
	}
  }
}         

// open url in a new browser instance
function goto_url(url) {
  if(url == '') {
    document.forms[0].reset();
    document.forms[0].elements[0].blur();
    return;
  }
  window.open(url,'helpwindow','toolbar=yes,location=yes,scrollbars=yes')
  document.forms[0].reset();
  document.forms[0].elements[0].blur();
}

function hide_dialog() {
  $(".dialog").hide();
}

function remove_dialog() {
  $(".dialog").remove();
}

function setup_buildresult_trigger() {

function br_trigger_mouseover() {
  if (lastTrigger && lastTrigger != this) {
    newTrigger = this;
    return false;
  }
  if (hideDelayTimer) clearTimeout(hideDelayTimer);
  if (beingShown || shown) {
    // don't trigger the animation again
    return;
  } else {
    // reset position of info box
    beingShown = true;
    $(info).find("#build_result_html").html("<div class='ajax_large_loader'></div>");
    var link = $(this).find(".build_result").attr("href");
    $.ajax({ error: function(request, status, thrown) {
	       $(info).find("#build_result_html").html("<span style='color: red'>Could not get build result</span>");
	     },
	     url: link,
	     success: function(data) {
	       $(info).find("#build_result_html").html(data);}
      });
    $(this).append(info);

    var topVal1 = $(this).height();
    var topVal2 = topVal1 + distance;
    info.css({
      top: topVal2 + "px",
      left: "0px",
      display: 'block',
      position: 'absolute'
    }).animate({
      top: topVal1 + "px",
      opacity: 1
    }, time, 'swing', 
      function() {
	beingShown = false;
	shown = true;
    });
    lastTrigger = this;
  }
  
  return false;
}

function br_trigger_mouseout() {
  if (hideDelayTimer) clearTimeout(hideDelayTimer);
  hideDelayTimer = setTimeout(function () {
				hideDelayTimer = null;
				info.animate({
				  top: '-=' + distance + 'px',
				  opacity: 0
				}, time, 'swing', 
			       function () {
				 shown = false;
				 lastTrigger = null;
				 info.css('display', 'none');
				 if (newTrigger) 
				   $(newTrigger).trigger("mouseover");
			       });
			      }, hideDelay);

  return false;
}


  var distance = 30;
  var time = 250;
  var hideDelay = 500;
  
  var hideDelayTimer = null;
  
  var beingShown = false;
  var shown = false;
  var info = $('#build_result_popup').css('opacity', 0);
  
  $(window).scroll(function () { 
		   shown = false;
		   lastTrigger = null;
		   info.css('display', 'none');
		 });
  
  var lastTrigger = null;
  var newTrigger = null;
  
  $(".build_result_trigger").mouseover(br_trigger_mouseover).mouseout(br_trigger_mouseout);

}

function setup_favorites() {
  var top = $('#global-navigation').height()-12;
  if ($.browser.webkit) top += 1;
  if (!$('#global-favorites').offset()) {
     return;
  }
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

}

function fillEmptyFields() {
  if( document.getElementById('username').value == '' ){
      document.getElementById('username').value = "_";
  }
  if( document.getElementById('password').value == '' ){
      document.getElementById('password').value = "_";
  }
}

