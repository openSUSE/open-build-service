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
//= require jquery3
//= require jquery_ujs
//= require peek
//= require popper
//= require bootstrap
//= require jquery
//= require jquery.ui.menu
//= require jquery.ui.autocomplete
//= require jquery.ui.tabs
//= require jquery.ui.tooltip
//= require jquery.tokeninput
//= require jquery.flot
//= require jquery.flot.resize
//= require jquery.flot.time
//= require jquery.flot.stack.js
//= require jquery_ujs
//= require datatables/jquery.dataTables
//= require datatables/dataTables.bootstrap4
//= require cocoon
//= require moment
//= require mousetrap
//= require peek
//= require webui/application/cm2/index
//
//= require webui/application/package
//= require webui2/project-wu2
//= require webui/application/request
//= require webui/application/patchinfo
//= require webui/application/comment
//= require webui/application/attribute
//= require webui/application/main
//= require webui/application/repository_tab
//= require webui/application/user
//= require webui/application/requests_table
//= require webui/application/image_templates
//= require webui/application/kiwi_editor
//= require webui/application/live_build_log
//= require webui/application/tabs
//= require webui/application/upload_jobs

// jquery.dataTables setup:
$(function () {
    $.extend($.fn.dataTable.defaults, {
        'iDisplayLength': 25,
    });
});

$(document).ready(function(){
  $('#group-members-table').dataTable();
});

function project_monitor_ready() {
    /* $(document).click(function() { $(".filterbox").hide(); });
     $(".filteritem input").click(function() { toggleCheck($(this)); toggleCheck($(this)); return true; });
     $(".filteritem").click(function() { toggleCheck($(this).find("input:first")); return false; }); */
    $("#statuslink").click(function () {
        toggleBox($(this), "#statusbox");
        $("#archbox").hide();
        $("#repobox").hide();
        return false;
    });
    $("#archlink").click(function () {
        toggleBox($(this), "#archbox");
        $("#statusbox").hide();
        $("#repobox").hide();
        return false;
    });
    $("#repolink").click(function () {
        toggleBox($(this), "#repobox");
        $("#archbox").hide();
        $("#statusbox").hide();
        return false;
    });

    $("#statusbox_close").click(function () {
        $("#statusbox").hide();
    });
    $("#statusbox_all").click(function () {
        $(".statusitem").prop("checked", true);
        return false;
    });
    $("#statusbox_none").click(function () {
        $(".statusitem").prop("checked", false);
        return false;
    });

    $("#archbox_close").click(function () {
        $("#archbox").hide();
    });
    $("#archbox_all").click(function () {
        $(".architem").prop("checked", true);
        return false;
    });
    $("#archbox_none").click(function () {
        $(".architem").prop("checked", false);
        return false;
    });

    $("#repobox_close").click(function () {
        $("#repobox").hide();
    });
    $("#repobox_all").click(function () {
        $(".repoitem").prop("checked", true);
        return false;
    });
    $("#repobox_none").click(function () {
        $(".repoitem").prop("checked", false);
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
