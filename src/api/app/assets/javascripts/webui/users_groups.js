function initializeUserConfigurationDatatable() { // jshint ignore:line
  initializeRemoteDatatable( // jshint ignore:line
    '#user-table',
    {
      pageLength: 50,
      columns: [
        { 'data': 'name' },
        { 'data': 'realname', 'visible': false },
        { 'data': 'local_user' },
        { 'data': 'state'},
        { 'data': 'actions', 'orderable': false, 'searchable': false }
      ]
    }
  );
}

function changeUserRole(obj) { // jshint ignore:line
  var type = obj.data("type");
  var role = obj.data("role");
  var spinner = obj.siblings('.fa-spinner');

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

  $.ajax({
    url: url,
    type: 'POST',
    data: data,
    beforeSend: function() {
      spinner.removeClass('d-none');
    },
    complete: function() {
      spinner.addClass('d-none');
    },
    success: function() {
      if (!obj.is(':checked') && obj.data('role') === 'maintainer') {
        window.location.reload();
      }
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

function initializeGroupTokenfield() { // jshint ignore:line
  var $tokenfield = $('#group-members.tag-input');

  $tokenfield.tagsInput({
    placeholder: 'Add a member',
    autocomplete: {
      minLength: 2,
      source: $tokenfield.data('source')
    }
  });
}
