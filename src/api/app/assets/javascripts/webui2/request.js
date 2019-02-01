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
          $('#supersede-display').removeClass('d-none');
          $('#supersede-requests').html(data);
        } else {
          $('#supersede-display').addClass('d-none');
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
          $('#devel-project-warning').removeClass('d-none');
          $('#devel-project-name').html(data);
        } else {
          $('#devel-project-warning').addClass('d-none');
        }
      }
    });
  }
}

function setupRequestDialog() { // jshint ignore:line
  $('#devel-project-name').click(function () {
    $('#targetproject').attr('value', $('#devel-project-name').html());
  });

  $('#targetproject').autocomplete({
    appendTo: '.modal-body',
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

function requestAddReviewAutocomplete() { // jshint ignore:line
  $('#review_type').change(function () {
    $('span').addClass('d-none');
    var selected = $('#review_type option:selected').attr('value');
    $('.' + selected).removeClass('d-none');
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

function collapseHistory(parent) { //jshint ignore:line
  var fullReqDescription = parent.find('#show-full-req-description');
  parent.find('#req-description').toggleClass('collapsed-history uncollapsed-history');
  fullReqDescription.toggleClass("collapsed-link uncollapsed-link");

  var showText = (fullReqDescription.attr('title') === 'show more' ) ?  'show less': 'show more';
  fullReqDescription.attr('title', showText);
}

function handleCollapseForHistory(origin) {  //jshint ignore:line
  $('.req-description-box').on('click', origin, function() {
    collapseHistory($(this).parents('.req-description-box'));
  });
}
