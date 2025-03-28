// TODO: rename without "Beta" after the rollout of 'request_show_redesign'.
function updateBuildResultBeta() { // jshint ignore:line
  var buildResultsUrl = $('.build-results-content .result').data('build-results-url');

  $('#build-reload').addClass('fa-spin');
  $.ajax({
    url: buildResultsUrl,
    data: Object.fromEntries(new URLSearchParams(location.search)), // jshint ignore:line
    success: function(data) {
      $('.build-results-content .result').html(data);
    },
    error: function() {
      $('.build-results-content .result').html('<p>No build results available</p>');
    },
    complete: function() {
      $('#build-reload').removeClass('fa-spin');
      setupProjectMonitorPage();
    }
  });
}

function setupProjectMonitorPage() {
  initializePopovers('[data-bs-toggle="popover"]'); // jshint ignore:line

  function setAllRelatedLinks(event) {
    $(this).closest('.dropdown-menu').find('input').prop('checked', event.data.checked);
  }

  $('.monitor-no-filter-link').on('click', { checked: false }, setAllRelatedLinks);
  $('.monitor-filter-link').on('click', { checked: true }, setAllRelatedLinks);
  $('.dropdown-menu.keep-open').on('click', function (e) {
    e.stopPropagation();
  });
  $('.monitor-search').on('input', function (e) {
    var labels = $(this).closest('.dropdown-menu').find('.form-check-label');
    Array.from(labels).forEach((label) => {
      var element = label.closest('.dropdown-item');
      element.classList.remove('d-none');
      if (!label.innerText.includes(e.target.value))
        element.classList.add('d-none');
    });
  });
}
