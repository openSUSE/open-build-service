var position_menu = function(button_id, menu_id) {
    var top = $('#global-navigation').height()+1;
    var left = $('#' + button_id).offset().left;
    $('#' + menu_id).css({left:'',top:''});
    $('#' + menu_id).offset({left:left,top:top});
}

$(document).ready(function() {

    if (!global_navigation_data) return;

    var html = '';

    $.each(global_navigation_data, function(i,menu){
        html += '<ul class="global-navigation-menu" id="menu-' + menu.id + '">';
        $.each(menu.items, function(j,submenu){
            html += '<li><a href="' + submenu.link +'">';
            html += '<span class="global-navigation-icon '+ submenu.image +'"></span>'; /*use imagemap and css */
            html += '<span>' + submenu.title + '</span>';
            html += '<span class="desc">' + submenu.desc + '</span>';
            html += '</a></li>';
        });
        html += '</ul>';
    });

    $('#global-navigation').after(html);

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

});
