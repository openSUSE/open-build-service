function updateSupersedeAndDevelPackageDisplay() {
  if ($('[id$="target_project"]').length > 0 && $('[id$="target_project"]')[0].value.length > 2) {
    if ($('[id$="target_project"]')[0].value === $('[id$="source_project"]')[0].value) {
      $('#sourceupdate-display').hide();
      $('[id$="sourceupdate"]').prop('disabled', true); // hide 'sourceupdate' from Ruby
    } else {
      $('#sourceupdate-display').show();
      $('[id$="sourceupdate"]').prop('disabled', false);
    }
    $.ajax({
      url: $('[id$="target_project"]').data('requests-url'),
      data: {
        project: $('[id$="target_project"]')[0].value,
        source_project: $('[id$="source_project"]')[0].value, // jshint ignore:line
        package: $('[id$="source_package"]')[0].value,
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
      url: $('[id$="target_project"]').data('develpackage-url'),
      data: {
        project: $('[id$="target_project"]')[0].value,
        package: $('[id$="source_package"]')[0].value
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

function setupSubmitPackagePage(url) { // jshint ignore:line
  $('#devel-project-name').click(function () {
    $('[id$="target_project"]').attr('value', $('#devel-project-name').html());
  });

  $('[id$="target_project"].obs-autocomplete').on('autocompleteselect autocompletechange', function() {
    updateSupersedeAndDevelPackageDisplay();
  });

  prefillSubmitRequestForm(url);
}

/*
  This prefills the dialog with data coming from the package prefill endpoint.
  FIXME: Remove this. The endpoint should be an instance method on the package model or inside a service object
 */
function prefillSubmitRequestForm(url) {
  $.ajax({
    url: url,
    dataType: 'json',
    contentType: 'application/json; charset=utf-8',
    accept: 'application/json',
    success: function (e) {
      $('[id$="target_package"]').attr('value', e.targetPackage);
      $('[id$="target_project"]').attr('value', e.targetProject);
      $('#bs_request_description').val(e.description);
      $('[id$="sourceupdate"]').attr('checked', e.cleanupSource);
      updateSupersedeAndDevelPackageDisplay();
    }
  });
}

function toggleAutocomplete(autocompleteElement) { // jshint ignore:line
  $('.hideable').addClass('d-none');
  $('.hideable input:not(:visible)').attr('disabled', true);

  var selected = $(autocompleteElement+':checked').attr('value');
  $('.' + selected).removeClass('d-none');
  $('.hideable input:visible').removeAttr('disabled');
}

// TODO: Rename once modals depending on the non-responsive-ux version are all removed
function requestAddAutocompleteResponsiveUx(autocompleteElement) { // jshint ignore:line
  toggleAutocomplete(autocompleteElement);

  $(autocompleteElement).change(function () { toggleAutocomplete(autocompleteElement); });
}

// TODO: Remove once modals depending on this are all removed
function requestAddAutocomplete(autocompleteElement) { // jshint ignore:line
  $('.modal').on('shown.bs.modal', function() {
    $('.hideable input:not(:visible)').attr('disabled', true);
  });

  $(autocompleteElement).change(function () {
    $('.hideable').addClass('d-none');
    $('.hideable input:not(:visible)').attr('disabled', true);

    var selected = $(autocompleteElement+' option:selected').attr('value');
    $('.' + selected).removeClass('d-none');
    $('.hideable input:visible').removeAttr('disabled');
    if ($('#review_package').is(':visible') && !$('#review_project').val()) {
      $('#review_package').attr('disabled', true);
    }
  });
}

$(document).ready(function(){
  var element = $('.bs-request-actions li:first-child a:first-child');
  if (element.length !== 0){
    loadDiffs($(element));
  }
  $('.request-tab[data-toggle="tab"]').on('shown.bs.tab', function () {
    var diffs = $(this).data('tab-pane-id');
    var tabPanes = $('.tab-content.sourcediff .tab-pane.sourcediff');

    if (Object.entries($('#'+diffs)).length === 0) {
      $.each( tabPanes, function(i){
        $(tabPanes[i]).removeClass('active');
      });
      loadDiffs($(this));
    } else {
      $.each( tabPanes, function(i){
        if(tabPanes[i].id !== diffs) {
          $(tabPanes[i]).removeClass('active');
        }
      });
    }
  });
});

function loadDiffs(element){
  $('.loading-diff').removeClass('invisible');
  var index = element.data('index');
  var url = element.data('url') + '?index=' + index;
  var diffLimit = $('.sourcediff').data('diff-limit');
  var diffToSuperseded = element.data('diff-to-superseded');
  if(diffLimit){
    url = url + '&full_diff=' + diffLimit;
  }
  if(diffToSuperseded){
    url = url + '&diff_to_superseded=' + diffToSuperseded;
  }
  $.ajax({
    url: url,
    success: function(){
      $('.loading-diff').addClass('invisible');
    }
  });
}
