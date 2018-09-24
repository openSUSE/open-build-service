
function changeUserRole(obj) { // jshint ignore:line
    var type = obj.data("type");
    var role = obj.data("role");
    var spinner = obj.next().children('i:first-child');

    var url;
    var data = {
        project: $('#involved-users').data("project"), 
        package: $('#involved-users').data("package"), 
        role: role
    };
    data[type + 'id'] = obj.data(type);
    if (obj.is(':checked')) {
        url = $('#involved-users').data("save-" + type);
    } else {
        url = $('#involved-users').data("remove");
    }

    spinner.removeClass('invisible');

    $.ajax({
        url: url,
        type: 'POST',
        data: data,
        complete: function () {
            spinner.addClass('invisible');
        }
    });
}

function setDataTableForUsersAndGroups() { // jshint ignore:line
    $('#user-table').dataTable({
        responsive: true,
        info: false,
        paging: false,
    });

    $('#group-table').dataTable({
        responsive: true,
        searching: false,
        info: false,
        paging: false
    });
}
