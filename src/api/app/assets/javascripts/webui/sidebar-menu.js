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
