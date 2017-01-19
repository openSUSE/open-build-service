var position_menu = function(button_id, menu_id) {
    var top = $('#global-navigation').height()+1;
    var left = $('#' + button_id).offset().left;
    $('#' + menu_id).css({left:'',top:''});
    $('#' + menu_id).offset({left:left,top:top});
};

$(function() {

    if (!global_navigation_data) return;

    // Build up navigation menus from localization data
    // then render it.

    $('#global-navigation').after(global_navigation_data.reduce(function(html, menu){
        return html
        + '<ul class="global-navigation-menu" id="menu-' + menu.id + '">'
        + menu.items.reduce(function(h, item){
            return h + '<li><a href="' + item.link +'">'
              + '<span class="global-navigation-icon '+ item.image +'"></span>' /*use imagemap and css */
              + '<span>' + item.title + '</span>'
              + '<span class="desc">' + item.desc + '</span>'
              + '</a></li>'
        }, '')
        + '</ul>'
    }, ''));

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
