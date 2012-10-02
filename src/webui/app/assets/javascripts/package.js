function makeServicesDragable() {
    $("#services").sortable( {
	placeholder: "empty_service",
	update: function(event, ui) {
	    var position = -1;
	    $(this).find(".service").each(function(index) {
		if ($(this).attr("id") == ui.item.attr("id")) { position = index; }
	    });
	    $("#services").animate({opacity: 0.2}, 500);
	    $("#services").sortable('disable');
	    $.ajax({
		type: 'post',
		url: $(this).data().url,
		data: { "item": ui.item.attr("id"),
			"position": position,
			"package": $(this).data().package,
			"project": $(this).data().project
		      },
		success: function(data) { 
		    $("#services").sortable('destroy');
		    $("#services_container").html(data); 
		    $("#services").sortable('enable');
		    $("#services").animate({opacity: 1}, 500);
		    makeServicesDragable();
		},
		error: function(data) {
		    $("#services").text(data);
                }
	    });
	}
    });
    $("#services").disableSelection();
}
