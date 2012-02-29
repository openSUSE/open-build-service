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


function setup_buildresult_tooltip(element_id, url) {
    $('#' + element_id).tooltip({
        showURL: false,
        track: true,
        fade: 250,
        opacity: 1,
        bodyHandler: function() {
            return "<div id='" + element_id + "_tooltip' style='width: 500px;'>loading buildresult...</div>";
        }
    });
    $('#' + element_id).mouseover(function() {
        if ($('#' + element_id + '_tooltip').html() == 'loading buildresult...') {
            $('#' + element_id + '_tooltip').load(url);
        }
    });
}


// include menu methods manually provided by bento menu otherwise
function setup_favorites() {
    if (!$('#item-favorites').offset()) {
        return;
    }
    $('#menu-favorites').hide();

    var position_menu = function(button_id, menu_id) {
        var top = $('#global-navigation').height()-12;
        if ($.browser.webkit) top += 1;
        var left = $('#' + button_id).offset().left-15;
        $('#' + menu_id).css({
            left:'',
            top:''
        });
        $('#' + menu_id).offset({
            left:left,
            top:top
        });
    }

    // copied from global-navigation.js
    $('#global-navigation li[id^=item-]').click(function(){
        var name = $(this).attr('id').substring(5);
        $("ul[id^=menu-]:visible").each(function() {
            $(this).fadeOut('fast');
        } );

        if( $(this).hasClass('selected') ) {
            $('#global-navigation li.selected').removeClass('selected');
        } else {
            $('#global-navigation li.selected').removeClass('selected');
            position_menu('item-' + name, 'menu-' + name);
            $('#menu-' + name).fadeIn();
            $(this).addClass('selected');
        }
        return false;
    });

    $('.global-navigation-menu').mouseleave(function(){
        $('#global-navigation li.selected').removeClass('selected');
        $(this).fadeOut();
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

function toggleBox(link, box) {
    //calculating offset for displaying popup message
    leftVal=link.position().left + "px";
    topVal=link.position().bottom + "px";
    $(box).css({
        left:leftVal,
        top:topVal
    }).toggle();
}

function toggleCheck(input) {
    if (input.attr("checked")) {
        input.removeAttr("checked");
    } else {
        input.attr("checked", "checked");
    }
}

function project_monitor_ready() {
    /* $(document).click(function() { $(".filterbox").hide(); });
  $(".filteritem input").click(function() { toggleCheck($(this)); toggleCheck($(this)); return true; });
  $(".filteritem").click(function() { toggleCheck($(this).find("input:first")); return false; }); */
    $("#statuslink").click(function() {
        toggleBox($(this), "#statusbox");
        $("#archbox").hide();
        $("#repobox").hide();
        return false;
    })
    $("#archlink").click(function() {
        toggleBox($(this), "#archbox");
        $("#statusbox").hide();
        $("#repobox").hide();
        return false;
    })
    $("#repolink").click(function() {
        toggleBox($(this), "#repobox");
        $("#archbox").hide();
        $("#statusbox").hide();
        return false;
    })

    $("#statusbox_close").click(function() {
        $("#statusbox").hide();
    } );
    $("#statusbox_all").click(function() {
        $(".statusitem").attr("checked", "checked");
        return false;
    });
    $("#statusbox_none").click(function() {
        $(".statusitem").attr("checked", false);
        return false;
    });

    $("#archbox_close").click(function() {
        $("#archbox").hide();
    } );
    $("#archbox_all").click(function() {
        $(".architem").attr("checked", "checked");
        return false;
    });
    $("#archbox_none").click(function() {
        $(".architem").attr("checked", false);
        return false;
    });

    $("#repobox_close").click(function() {
        $("#repobox").hide();
    } );
    $("#repobox_all").click(function() {
        $(".repoitem").attr("checked", "checked");
        return false;
    });
    $("#repobox_none").click(function() {
        $(".repoitem").attr("checked", false);
        return false;
    });
}

function monitor_ready() {
    $(".scheduler_status").hover(
        function () {
            $(this).find(".statustext").fadeIn();
        },
        function () {
            $(this).find(".statustext").hide();
        }
        );
}

function resizeMonitorBoxes()
{
    return; /* needs work */
    var largestbox = new Object();
    $(".builderbox").each(function() {
        var h = $(this).height();
        var t = $(this).position().top;
        if (!largestbox[t] || (h > largestbox[t])) {
            largestbox[t] = h;
        }
    });
    $(".builderbox").each(function() {
        var h = $(this).height();
        var nh = largestbox[$(this).position().top];
        if (h != nh) {
            console.log("set %d", nh);
            if (nh) {
                $(this).height( largestbox[$(this).position().top] );
            }
            resizeMonitorBoxes();
            return;
        }
    });
  
}

$(document).ajaxSend(function(event, request, settings) {
  if (typeof(CSRF_PROTECT_AUTH_TOKEN) == "undefined") return;
  // settings.data is a serialized string like "foo=bar&baz=boink" (or null)
  settings.data = settings.data || "";
  settings.data += (settings.data ? "&" : "") + "authenticity_token=" + encodeURIComponent(CSRF_PROTECT_AUTH_TOKEN);
});

