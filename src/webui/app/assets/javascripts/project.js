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
