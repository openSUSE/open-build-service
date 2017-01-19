function renderPackagesTable(wrapper, packages, length) {
    length = (typeof length === "undefined") ? 25 : length;
    var packageurl = $("#" + wrapper).data("url");
    $("#" + wrapper).html('<table cellpadding="0" cellspacing="0" border="0" class="compact stripe" id="' + wrapper + '_table"></table>');
    $("#" + wrapper + "_table").dataTable({
        "data": packages,
        "ordering": true,
        "paging": packages.length > 12,
        "autoWidth": false,
        "pagingType": "simple",
        "columns": [
            {
                "title": "Name",
                "width": "70%",
                "render": function (obj) {
                    var url = packageurl.replace(/REPLACEIT/, obj);
                    return '<a href="' + url + '">' + obj + '</a>';
                }
            },
            {
                "title": "Changed",
                "width": "30%",
                "render": function (obj) {
                    var fromnow = moment.unix(parseInt(obj)).fromNow();
                    if (fromnow.match(/^in\s/)) {
                        fromnow = "now"; // in case server time is ahead of client
                    }
                    return '<span class="hidden">' + obj + '</span>' + fromnow;
                }
            }
        ],
        "pageLength": length,
        "stateSave": true
    });
}

function renderProjectsTable(length) {
    length = (typeof length === "undefined") ? 25 : length;
    var projects = main_projects;
    if (!$('#excludefilter').is(":checked"))
        projects = projects.concat(excl_projects);
    var projecturl = $("#projects_table_wrapper").data("url");
    $("#projects_table_wrapper").html('<table cellpadding="0" cellspacing="0" border="0" class="compact stripe" id="projects_table"></table>');
    $("#projects_table").dataTable({
        "data": projects,
        "paging": true,
        "pagingType": "simple",
        "columns": [
            {
                "title": "Name",
                "render": function (obj, type, data_row, meta) {
                    var url = projecturl.replace(/REPLACEIT/, data_row[0]);
                    return '<a href="' + url + '">' + data_row[0] + '</a>';
                }
            },
            { "title": "Title" }
        ],
        "pageLength": length,
        "stateSave": true
    });
}

function renderPackagesProjectsTable(options) {
    var length = options.length || 25;
    var name = options.name || "packages_projects_wrapper";

    var packageurl = $("#" + name).data("url");
    $("#" + name).html("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" class=\"compact stripe\" id=\"" + name + '_table' + "\"></table>");
    $("#" + name + "_table").dataTable(
        {
            "data": options.packages,
            "paging": options.packages.length > 12,
            "pagingType": "simple",
            "columns": [
                {
                    "title": "Package",
                    "render": function (obj, type, data_row, meta) {
                        var url1 = packageurl.replace(/REPLACEPKG/, data_row[0]);
                        var url = url1.replace(/REPLACEPRJ/, data_row[1]);
                        return '<a href="' + url + '">' + data_row[0] + '</a>';
                    }
                },
                {
                    "columns.title": "Project"
                }
            ],
            "pageLength": length,
            "stateSave": true
        });
}


function autocomplete_repositories(project_name) {
    if (project_name === "")
        return;
    $('#loader-repo').show();
    $('#add_repository_button').prop('disabled', true);
    $('#target_repo').prop('disabled', true);
    $('#repo_name').prop('disabled', true);
    $.ajax({
        url: $('#target_repo').data('ajaxurl'),
        data: {project: project_name},
        success: function (repos) {
            $('#target_repo').html('');
            // suggest a name:
            $('#repo_name').attr('value', project_name.replace(/:/g, '_') + '_' + repos[0]);
            if(repos.length === 0) {
                $('#target_repo').append(new Option('No repos found'));
                return;
            }

            $('#target_repo').prop('disabled', false);
            $('#repo_name').prop('disabled', false);
            $('#add_repository_button').prop('disabled', false);
            $('#target_repo').append(repos.map(function(repo) {
                return new Option(repo);
            }));
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
        'paging': false,
        'searching': false,
        'info': false
    });
    $('#subprojects_table').dataTable({
        'paging': false,
        'searching': false,
        'info': false
    });

}
