// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery.ui.menu
//= require jquery.ui.autocomplete
//= require jquery.ui.tabs
//= require jquery.ui.tooltip
//= require jquery.tokeninput
//= require jquery_ujs
//= require dataTables/jquery.dataTables
//= require cocoon
//
//= require webui/application/jquery.expander.js
//= require webui/application/jquery.flot.js
//= require webui/application/jquery.flot.stack.js
//= require webui/application/bento/script.js
//= require webui/application/bento/global-navigation.js
//= require webui/application/bento/l10n/global-navigation-data-en_US.js
//= require webui/application/package
//= require webui/application/project
//= require webui/application/request
//= require webui/application/patchinfo
//= require webui/application/comment
//= require webui/application/attribute
//= require webui/application/main
//= require webui/application/repository_tab

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
    if (url == '') {
        document.forms[0].reset();
        document.forms[0].elements[0].blur();
        return;
    }
    window.open(url, 'helpwindow', 'toolbar=yes,location=yes,scrollbars=yes')
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
        content: function () {
            return "<div id='" + element_id + "_tooltip' style='width: 500px;'>loading buildresult...</div>";
        }
    });
    $('#' + element_id).mouseover(function () {
        if ($('#' + element_id + '_tooltip').html() == 'loading buildresult...') {
            $('#' + element_id + '_tooltip').load(url);
        }
    });
}

function fillEmptyFields() {
    if (document.getElementById('username').value == '') {
        document.getElementById('username').value = "_";
    }
    if (document.getElementById('password').value == '') {
        document.getElementById('password').value = "_";
    }
}

function toggleBox(link, box) {
    //calculating offset for displaying popup message
    leftVal = link.position().left + "px";
    topVal = link.position().bottom + "px";
    $(box).css({
        left: leftVal,
        top: topVal
    }).toggle();
}

function toggleCheck(input) {
    if (input.is(":checked")) {
        input.removeAttr("checked");
    } else {
        input.attr("checked", "checked");
    }
}

function project_monitor_ready() {
    /* $(document).click(function() { $(".filterbox").hide(); });
     $(".filteritem input").click(function() { toggleCheck($(this)); toggleCheck($(this)); return true; });
     $(".filteritem").click(function() { toggleCheck($(this).find("input:first")); return false; }); */
    $("#statuslink").click(function () {
        toggleBox($(this), "#statusbox");
        $("#archbox").hide();
        $("#repobox").hide();
        return false;
    })
    $("#archlink").click(function () {
        toggleBox($(this), "#archbox");
        $("#statusbox").hide();
        $("#repobox").hide();
        return false;
    })
    $("#repolink").click(function () {
        toggleBox($(this), "#repobox");
        $("#archbox").hide();
        $("#statusbox").hide();
        return false;
    })

    $("#statusbox_close").click(function () {
        $("#statusbox").hide();
    });
    $("#statusbox_all").click(function () {
        $(".statusitem").attr("checked", "checked");
        return false;
    });
    $("#statusbox_none").click(function () {
        $(".statusitem").attr("checked", false);
        return false;
    });

    $("#archbox_close").click(function () {
        $("#archbox").hide();
    });
    $("#archbox_all").click(function () {
        $(".architem").attr("checked", "checked");
        return false;
    });
    $("#archbox_none").click(function () {
        $(".architem").attr("checked", false);
        return false;
    });

    $("#repobox_close").click(function () {
        $("#repobox").hide();
    });
    $("#repobox_all").click(function () {
        $(".repoitem").attr("checked", "checked");
        return false;
    });
    $("#repobox_none").click(function () {
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

function resizeMonitorBoxes() {
    return;
    /* needs work */
    var largestbox = new Object();
    $(".builderbox").each(function () {
        var h = $(this).height();
        var t = $(this).position().top;
        if (!largestbox[t] || (h > largestbox[t])) {
            largestbox[t] = h;
        }
    });
    $(".builderbox").each(function () {
        var h = $(this).height();
        var nh = largestbox[$(this).position().top];
        if (h != nh) {
            console.log("set %d", nh);
            if (nh) {
                $(this).height(largestbox[$(this).position().top]);
            }
            resizeMonitorBoxes();
            return;
        }
    });

}

function insertServiceRow() {
    var name = $('#add_new_parameter').value;
    var service = $('#servicename').value;
    var value = $('#add_new_value').value;
    var number = $('#count_parameters').value + 1;

    $('#pTable tr:last').before('<tr class=\"row_' + number + '\">' +
        '<td>' + name + '</td>' +
        '<td id="added_parameter_' + number + '">...</td>' +
        '<td><a href=\"#\" onclick=\"\$(\'tr.row_' + number + '\').remove(); return false;\">X</a></td>' +
        '</tr>');

    document.getElementById('count_parameters').value = number;

    var path = "/package/service_parameter_value?number=" + number + "&servicename=" + encodeURIComponent(service) + "&parameter=" + encodeURIComponent(name) + "&value=" + encodeURIComponent(value) + "&package=<%= CGI.escape(@package.name) %>&project=<%= CGI.escape(@project.name) %>";
    $("#pTable td#added_parameter_" + number).load(path);
}

function callPiwik() {
    var u = (("https:" == document.location.protocol) ? "https://beans.opensuse.org/piwik/" : "http://beans.opensuse.org/piwik/");
    _paq.push(['setSiteId', 8]);
    _paq.push(['setTrackerUrl', u + 'piwik.php']);
    _paq.push(['trackPageView']);
    _paq.push(['setDomains', ["*.opensuse.org"]]);
    var d = document,
        g = d.createElement('script'),
        s = d.getElementsByTagName('script')[0];
    g.type = 'text/javascript';
    g.defer = true;
    g.async = true;
    g.src = u + 'piwik.js';
    s.parentNode.insertBefore(g, s);
}

$(document).ajaxSend(function (event, request, settings) {
    if (typeof(CSRF_PROTECT_AUTH_TOKEN) == "undefined") return;
    // settings.data is a serialized string like "foo=bar&baz=boink" (or null)
    settings.data = settings.data || "";
    settings.data += (settings.data ? "&" : "") + "authenticity_token=" + encodeURIComponent(CSRF_PROTECT_AUTH_TOKEN);
});

// Could be handy elsewhere ;-)
var URL_REGEX = /\b((?:[a-z][\w-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))/gi;

// jquery.dataTables setup:
$(document).ready(function () {
    $.extend($.fn.dataTable.defaults, {
        'iDisplayLength': 25,
    });
});

function change_role(obj) {
    var td = obj.parent("td");
    var type = td.data("type");
    var role = td.data("role");

    var url;
    data = {project: $('#involved_users').data("project"), package: $('#involved_users').data("package"), role: role};
    data[type + 'id'] = td.data(type);
    if (obj.is(':checked')) {
        url = $('#involved_users').data("save-" + type);
    } else {
        url = $('#involved_users').data("remove")
    }

    $('#' + type + '_spinner').show();
    $('#' + type + '_table input').animate({opacity: 0.2}, 500);
    $('#' + type + '_table input').attr("disabled", "true");

    $.ajax({
        url: url,
        type: 'POST',
        data: data,
        complete: function () {
            $('#' + type + '_spinner').hide();
            $('#' + type + '_table input').animate({opacity: 1}, 200);
            $('#' + type + '_table input').removeAttr('disabled');
        }
    });
}

function collapse_expand(file_id) {
    placeholder = $('#diff_view_' + file_id + '_placeholder');
    if (placeholder.attr('id')) {
        $.ajax({
            url: placeholder.parents('.table_wrapper').data("url"),
            type: 'POST',
            data: { text: placeholder.text(), uid: placeholder.data('uid') },
            success: function (data) {
                $('#diff_view_' + file_id).show();
                $('#diff_view_' + file_id + '_placeholder').html(data);
                $('#diff_view_' + file_id + '_placeholder').attr('id', '');
                use_codemirror(placeholder.data('uid'), true, placeholder.data("mode"));
                $('#collapse_' + file_id).show();
                $('#expand_' + file_id).hide();
            },
            error: function (data) {
                $('#diff_view_' + file_id).hide();
                $('#collapse_' + file_id).hide();
                $('#expand_' + file_id).show();
            },
        });
    } else {
        $('#diff_view_' + file_id).toggle();
        $('#collapse_' + file_id).toggle();
        $('#expand_' + file_id).toggle();
    }
}

// used in testing
function select_from_autocomplete(toselect) {
    $('ul.ui-autocomplete li.ui-menu-item a').each(function (index) {
        if ($(this).text() == toselect) { $(this).trigger('mouseenter').click(); }
    });
}
