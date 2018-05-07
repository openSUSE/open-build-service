function updateSupersedeAndDevelPackageDisplay() {
  if ($('#targetproject').length > 0 && $('#targetproject')[0].value.length > 2) {
    if ($('#targetproject')[0].value === $('#sourceproject')[0].value) {
      $('#sourceupdate-display').hide();
      $('#sourceupdate').prop('disabled', true); // hide 'sourceupdate' from Ruby
    } else {
      $('#sourceupdate-display').show();
      $('#sourceupdate').prop('disabled', false);
    }
    $.ajax({
      url: $('#targetproject').data('requests-url'),
      data: {
        project: $('#targetproject')[0].value,
        source_project: $('#project')[0].value, // jshint ignore:line
        package: $('#package')[0].value,
        types: 'submit',
        states: ['new', 'review', 'declined']
      },
      success: function (data) {
        if (data.indexOf('No requests') === -1) {
          $('#supersede-display').show();
          $('#supersede-requests').html(data);
        } else {
          $('#supersede-display').hide();
          $('#supersede-requests').html('');
        }
      }
    });
    $.ajax({
      url: $('#targetproject').data('develpackage-url'),
      data: {
        project: $('#targetproject')[0].value,
        package: $('#package')[0].value
      },
      success: function (data) {
        if (data.length > 0) {
          $('#devel-project-warning').show();
          $('#devel-project-name').html(data);
        } else {
          $('#devel-project-warning').hide();
        }
      }
    });
  }
}

function setup_request_dialog() { // jshint ignore:line
  $('#devel-project-name').click(function () {
    $('#targetproject').attr('value', $('#devel-project-name').html());
  });

  $('#targetproject').autocomplete({
    source: $('#targetproject').data('autocomplete-url'),
    search: function() {
      $(this).addClass('loading-spinner');
    },
    response: function() {
      $(this).removeClass('loading-spinner');
    },
    minLength: 2,
    select: updateSupersedeAndDevelPackageDisplay,
    change: updateSupersedeAndDevelPackageDisplay,
    max: 50
  });

  updateSupersedeAndDevelPackageDisplay();
}

/*$("#targetpackage").autocomplete('<%= url_for :controller => :project, :action => :autocomplete_packages %>', {
 minChars: 0, matchCase: true, max: 50, extraParams: {project: function() { return $("#target_project").val(); }}
 });*/

function requestAddAcceptRequestButton() { // jshint ignore:line
  $('#accept_request_button').click(function () {
    var additionalElement;

    /* Add some hidden elements to carry HTML form data that is found at other DOM places for design reasons.  */
    if ($('.submitter_is_maintainer_checkbox').size() !== 0 &&
      $('.submitter_is_maintainer_checkbox').is(':checked')) {
      additionalElement = '<input id="' + $('.submitter_is_maintainer_checkbox').attr('id') +
        '" name="' + $('.submitter_is_maintainer_checkbox').attr('name') +
        '" type="hidden" value="' + $('.submitter_is_maintainer_checkbox').attr('value') + '"/>';
      $('#request_handle_form p:last').append(additionalElement);
    }
    if ($('.forward_checkbox').size() !== 0 &&
      $('.forward_checkbox').is(':checked')) {
      $('.forward_checkbox').each(function () {
        additionalElement = '<input id="' + $(this).attr('id') +
          '" name="' + $(this).attr('name') +
          '" type="hidden" value="' + $(this).attr('value') + '"/>';
        $('#request_handle_form p:last').append(additionalElement);
      });
    }
  });
}

function requestShowReview() { // jshint ignore:line
  var index;
  $('.review_descision_link').click(function (event) {
    $('#review_descision_select li.selected').attr('class', '');
    $(event.target).parent().attr('class', 'selected');
    $('.review_descision_display').hide();
    index = event.target.id.split('review_descision_link_')[1];
    $('#review_descision_display_' + index).show();
    return false;
  });
}

function requestAddReviewAutocomplete() { // jshint ignore:line

  $('#review_type').change(function () {
    switch ($('#review_type option:selected').attr('value')) {
      case "user":
      {
        $('#review_user_span').show();
        $('#review_group_span').hide();
        $('#review_project_span').hide();
        $('#review_package_span').hide();
      }
        break;
      case "group":
      {
        $('#review_user_span').hide();
        $('#review_group_span').show();
        $('#review_project_span').hide();
        $('#review_package_span').hide();
      }
        break;
      case "project":
      {
        $('#review_user_span').hide();
        $('#review_group_span').hide();
        $('#review_project_span').show();
        $('#review_package_span').hide();
      }
        break;
      case "package":
      {
        $('#review_user_span').hide();
        $('#review_group_span').hide();
        $('#review_project_span').show();
        $('#review_package_span').show();
      }
        break;
    }
  });

  $("#review_group").autocomplete({source: '/group/autocomplete', minChars: 2, matchCase: true, max: 50,
  search: function() {
    $(this).addClass('loading-spinner');
  },
  response: function() {
    $(this).removeClass('loading-spinner');
  }});
  $("#review_user").autocomplete({source: '/user/autocomplete', minChars: 2, matchCase: true, max: 50,
  search: function() {
    $(this).addClass('loading-spinner');
  },
  response: function() {
    $(this).removeClass('loading-spinner');
  }});
  $("#review_project").autocomplete({source: '/project/autocomplete_projects', minChars: 2, matchCase: true, max: 50,
  search: function() {
    $(this).addClass('loading-spinner');
  },
  response: function() {
    $(this).removeClass('loading-spinner');
  }});
  $("#review_package").autocomplete({
    source: function (request, response) {
      $.ajax({
        url: '/project/autocomplete_packages',
        dataType: "json",
        data: {
          term: request.term,
          project: $("#review_project").val()
        },
        success: function (data) {
          response(data);
        }
      });
    },
    search: function() {
      $(this).addClass('loading-spinner');
    },
    response: function() {
      $(this).removeClass('loading-spinner');
    },
    minLength: 2,
    minChars: 0,
    matchCase: true,
    max: 50
  });
}

function setupActionLink() { // jshint ignore:line
  var index;
  $('.action_select_link').click(function (event) {
    $('#action_select li.selected').attr('class', '');
    $(event.target).parent().attr('class', 'selected');
    $('.action_display').hide();
    index = event.target.id.split('action_select_link_')[1];
    $('#action_display_' + index).show();
    // It is necessary to refresh the CodeMirror editors after switching tabs to initialise the dimensions again.
    // Otherwise the editors are empty after calling show().
    editors.forEach( function(editor) { editor.refresh(); });
    return false;
  });
}
