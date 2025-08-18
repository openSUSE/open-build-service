// Remove this after PackageController#rdiff moves to DiffListComponent
$(function ($) {
  $('body').on('click', '.expand-diffs', function () {
    var forPackage = $(this).data('package');
    var details = $('details.card[data-package="' + forPackage + '"]');
    details.attr('open', 'open');
  });

  $('body').on('click', '.collapse-diffs', function () {
    var forPackage = $(this).data('package');
    var details = $('details.card[data-package="' + forPackage + '"]');
    details.attr('open', null);
  });
});

$(document).ready(function() {
  setupRpmlintFilters();
  $('.btn-more').click(function() {
    var moreInfo = $('.more_info');
    moreInfo.toggleClass('d-none');
    $(this).text(moreInfo.hasClass('d-none') ? 'more info' : 'less info');
  });
});

function setupRpmlintFilters() {
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
