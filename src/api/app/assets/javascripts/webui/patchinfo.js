function setupPatchinfo() { // jshint ignore:line
  addIssuesAjaxBefore();
  addIssuesAjaxSuccess();
  addIssuesAjaxComplete();
  deleteIssueClick();
  patchinfoBlockChange();
  patchinfoBinariesEvents();
}

function addIssuesAjaxBefore() {
  $('#add-issues').on('ajax:before', function() {
    var issues = $('#issue_ids').val();
    if (issues.length === 0) {
      return false;
    }

    issues = $.unique(issues.replace(/ /g, '').split(','));

    var currentIssues = $('[name="patchinfo[issueid][]"]').map(function(_, element) {
      var issueId = element.id;
      if (issueId.startsWith('issueid_cve')) {
        return issueId.replace('issueid_cve_', '');
      } else {
        return issueId.replace('issueid_', '').replace('_', '#');
      }
    }).toArray();

    issues = issues.filter(function(issue) {
      return currentIssues.indexOf(issue) === -1;
    });

    if (issues.length === 0) {
      $('#issue_ids').val('');
      return false;
    }

    var element = $(this);
    element.children('i.fas.fa-plus-circle').addClass('d-none');
    element.children('i.fas.fa-spin').removeClass('d-none');
    element.data('params', { issues: issues, project: element.data('project') });
  });
}

function addIssuesAjaxSuccess() {
  $('#add-issues').on('ajax:success', function(event, data) {
    $('#ajax-error-message').text(data.error);
    if (data.error !== '') {
      return;
    }

    addIssues(data.issues);
  });
}

function addIssues(issues) {
  $.each(issues, function() {
    var issueTracker = this[0];
    var issueId = this[1];
    var issueUrl = this[2];
    var issueSum = this[3];

    if ($('li#issue_' + issueTracker + '_' + issueId).length > 0) {
      return;
    }

    addIssuesHtml(issueTracker, issueId, issueUrl, issueSum);
  });
}

function addIssuesHtml(issueTracker, issueId, issueUrl, issueSum) {
  var identifier = issueTracker + '_' + issueId;

  $('#issues').append(
    $('<div>', { id: 'issue_' + identifier, class: 'list-group-item flex-column align-items-start issue-element' }).append(
      $('<div>', { class: 'd-flex w-100 mb-1' }).append(
        $('<a>', { href: issueUrl, target: '_blank', rel: 'noopener' }).append(
          $('<i>', { class: 'fa fa-bug text-danger' })
        ).append(' ' + issueTracker + '#' + issueId),
        $('<a>', { id: 'delete_issue_' + identifier, href: '#', title: 'Delete', class: 'ms-1' }).append(
          $('<i>', { class: 'fas fa-times-circle text-danger' })
        ),
        $('<input>', { type: 'hidden', name: 'patchinfo[issueid][]', id: 'issueid_' + identifier, value: issueId, multiple: true }),
        $('<input>', { type: 'hidden', name: 'patchinfo[issuetracker][]', id: 'issuetracker_' + identifier, value: issueTracker, multiple: true }),
        $('<input>', { type: 'hidden', name: 'patchinfo[issueurl][]', id: 'issueurl_' + identifier, value: issueUrl, multiple: true }),
        $('<input>', { type: 'hidden', name: 'patchinfo[issuesum][]', id: 'issueurl_' + identifier, value: issueSum, multiple: true })),
      $('<small>', { class: 'text-muted' }).append(issueSum)
    )
  );
}

function addIssuesAjaxComplete() {
  $('#add-issues').on('ajax:complete', function() {
    var element = $(this);
    element.children('i.fas.fa-spin').addClass('d-none');
    element.children('i.fas.fa-plus-circle').removeClass('d-none');
    $('#issue_ids').val('');
  });
}

function deleteIssueClick() {
  $(document).on('click', 'a[id^="delete_issue_"]', function(event) {
    event.preventDefault();

    $(this).parents('.issue-element').remove();
  });
}

function patchinfoBlockChange() {
  $('#patchinfo_block').change(function() {
    $('#patchinfo_block_reason').prop('disabled', !this.checked);
  });
}

function patchinfoBinariesEvents() {
  // Without this, selected binaries are always reset
  $("form").submit(function () {
    $('#patchinfo_binaries option').prop('selected', true);
    $('#available_binaries option').prop('selected', true);
  });

  $('#select-binary').click(function () {
    $("#patchinfo_binaries option[value='']").remove();
    moveBinaries('#available_binaries', '#patchinfo_binaries');
  });
  $('#select-binaries').click(function () {
    $("#patchinfo_binaries option[value='']").remove();
    $('#available_binaries option').prop('selected', 'true');
    moveBinaries('#available_binaries', '#patchinfo_binaries');
  });
  $('#unselect-binaries').click(function () {
    $('#patchinfo_binaries option').prop('selected', 'true');
    moveBinaries('#patchinfo_binaries', '#available_binaries');
  });
  $('#unselect-binary').click(function () {
    moveBinaries('#patchinfo_binaries', '#available_binaries');
  });
}

function moveBinaries(source, destination) {
  var selected = $(source + ' option:selected').remove();
  var sorted = $.makeArray($(destination + ' option').add(selected)).sort(function (a, b) {
    return $(a).text() > $(b).text() ? 1 : -1;
  });
  $(destination).empty().append(sorted);
}
