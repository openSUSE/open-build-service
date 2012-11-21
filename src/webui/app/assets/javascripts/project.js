function renderPackagesTable(packages)
{
    var packageurl = $("#packages_table_wrapper").data("url");
    $("#packages_table_wrapper").html( '<table cellpadding="0" cellspacing="0" border="0" class="display" id="packages_table"></table>' );
    $("#packages_table").dataTable( {"aaData": packages, 
				     "bSort": false,
				     "bPaginate": packages.length > 12,
				     "aoColumns": [
					 {
					     "fnRender": function ( obj ) {
						 var url = packageurl.replace(/REPLACEIT/, encodeURIComponent(obj.aData));
						 return '<a href="' + url +'">' + obj.aData + '</a>';
					     }
					 } ]
				    });
}

function autocomplete_repositories(project_name) 
{
    $('#loader-repo').show();
    $('#add_repository_button').attr('disabled', 'true');
    $('#target_repo').attr('disabled', 'true');
    $('#repo_name').attr('disabled', 'true');
    $.ajax({
	url: $('#target_repo').data('ajaxurl'),
	data: {project: project_name},
	success: function(data){
	    $('#target_repo').html('');
	    // suggest a name:
            $('#repo_name').attr('value', project_name.replace(/:/g,'_') + '_' + data[0]);
	    var foundoptions = false;
            $.each(data, function(idx, val) {
		$('#target_repo').append( new Option( val ) );
		$('#target_repo').removeAttr('disabled');
         	$('#repo_name').removeAttr('disabled');
		$('#add_repository_button').removeAttr('disabled');
		foundoptions = true;
            });
	    if (!foundoptions)
		$('#target_repo').append( new Option( 'No repos found') );
	},
	complete: function(data){
            $('#loader-repo').hide();
	}
    });
}

function repositories_setup_autocomplete()
{
    $("#target_project").autocomplete({
	source: $('#target_project').data('ajaxurl'),
	minLength: 2,
	select: function (event, ui) { autocomplete_repositories(ui.item.value); },
	change: function () { autocomplete_repositories($('#target_project').attr('value')); },
    });
    
    $("#target_project").change(function() {
	autocomplete_repositories($('#target_project').attr('value'));
    });
  
    $('#target_repo').change(function() {
	$('#repo_name').attr('value', $("#target_project").attr('value').replace(/:/g,'_') + '_' + $(this).val());
    });
}
