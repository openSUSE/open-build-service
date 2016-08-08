function renderPackagesTable(wrapper, packages, length) {
    length = (typeof length === "undefined") ? 25 : length;
    var packageurl = $("#" + wrapper).data("url");
    $("#" + wrapper).html('<table cellpadding="0" cellspacing="0" border="0" class="display" id="' + wrapper + '_table"></table>');
    $("#" + wrapper + "_table").dataTable({"aaData": packages,
        "bSort": false,
        "bPaginate": packages.length > 12,
        "aoColumns": [
            {
                "mData": function (obj) {
                    var url = packageurl.replace(/REPLACEIT/, obj[0]);
                    return '<a href="' + url + '">' + obj[0] + '</a>';
                },
                "fnRender": function (obj) {
                    var url = packageurl.replace(/REPLACEIT/, obj.aData);
                    return '<a href="' + url + '">' + obj.aData + '</a>';
                }
            }
        ],
        "iDisplayLength": length,
        "bStateSave": true
    });
}

function renderProjectsTable(length) {
    length = (typeof length === "undefined") ? 25 : length;
    var projects = main_projects;
    if (!$('#excludefilter').is(":checked"))
        projects = projects.concat(excl_projects);
    var projecturl = $("#projects_table_wrapper").data("url");
    $("#projects_table_wrapper").html('<table cellpadding="0" cellspacing="0" border="0" class="display" id="projects_table"></table>');
    $("#projects_table").dataTable({"aaData": projects,
        "bPaginate": true,
        "aoColumns": [
            {
                "sTitle": "Name",
                "mData": function (obj) {
                    var url = projecturl.replace(/REPLACEIT/, obj[0]);
                    return '<a href="' + url + '">' + obj[0] + '</a>';
                },
                "fnRender": function (obj) {
                    var url = projecturl.replace(/REPLACEIT/, obj.aData[0]);
                    return '<a href="' + url + '">' + obj.aData[0] + '</a>';
                }
            },
            { "sTitle": "Title" }
        ],
        "iDisplayLength": length,
        "bStateSave": true
    });
}

function renderPackagesProjectsTable(options) {
    var length = options.length || 25;
    var name = options.name || "packages_projects_wrapper";

    var packageurl = $("#" + name).data("url");
    $("#" + name).html("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" class=\"display\" id=\"" + name + '_table' + "\"></table>");
    $("#" + name + "_table").dataTable(
        {
            "aaData": options.packages,
            "bPaginate": options.packages.length > 12,
            "aoColumns": [
                {
                    "sTitle": "Package",
                    "mData": function (obj) {
                        var url1 = packageurl.replace(/REPLACEPKG/, obj[0]);
                        var url = url1.replace(/REPLACEPRJ/, obj[1]);
                        return '<a href="' + url + '">' + obj[0] + '</a>';
                    },
                    "fnRender": function (obj) {
                        var url1 = packageurl.replace(/REPLACEPKG/, obj.aData[0]);
                        var url = url1.replace(/REPLACEPRJ/, obj.aData[1]);
                        return '<a href="' + url + '">' + obj.aData[0] + '</a>';
                    }
                },
                {
                    "sTitle": "Project"
                }
            ],
            "iDisplayLength": length,
            "bStateSave": true
        });
}


function autocomplete_repositories(project_name) {
    if (project_name === "")
        return;
    $('#loader-repo').show();
    $('#add_repository_button').attr('disabled', 'true');
    $('#target_repo').attr('disabled', 'true');
    $('#repo_name').attr('disabled', 'true');
    $.ajax({
        url: $('#target_repo').data('ajaxurl'),
        data: {project: project_name},
        success: function (data) {
            $('#target_repo').html('');
            // suggest a name:
            $('#repo_name').attr('value', project_name.replace(/:/g, '_') + '_' + data[0]);
            var foundoptions = false;
            $.each(data, function (idx, val) {
                $('#target_repo').append(new Option(val));
                $('#target_repo').removeAttr('disabled');
                $('#repo_name').removeAttr('disabled');
                $('#add_repository_button').removeAttr('disabled');
                foundoptions = true;
            });
            if (!foundoptions)
                $('#target_repo').append(new Option('No repos found'));
        },
        complete: function (data) {
            $('#loader-repo').hide();
        }
    });
}

function repositories_setup_autocomplete() {
    $("#target_project").autocomplete({
        source: $('#target_project').data('ajaxurl'),
        minLength: 2,
        select: function (event, ui) {
            autocomplete_repositories(ui.item.value);
        },
        change: function () {
            autocomplete_repositories($('#target_project').attr('value'));
        },
    });

    $("#target_project").change(function () {
        autocomplete_repositories($('#target_project').attr('value'));
    });

    $('#target_repo').select(function () {
        $('#repo_name').attr('value', $("#target_project").attr('value').replace(/:/g, '_') + '_' + $(this).val());
    });
}

function setup_subprojects_tables() {
    $('#parentprojects_table').dataTable({
        'bPaginate': false,
        'bFilter': false,
        'bInfo': false,
    });
    $('#subprojects_table').dataTable({
        'bPaginate': false,
        'bFilter': false,
        'bInfo': false,
    });

}
