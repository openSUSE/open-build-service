/* exported setupDropdownFilters */
/* global initializePopovers */

$(document).ready(function(){
  // Dismiss dropdowns using a button with `data-bs-dismiss` value
  const dropdownDismissList = document.querySelectorAll('[data-bs-dismiss="dropdown"]');

  dropdownDismissList.forEach((dismiss) => {
    dismiss.addEventListener( 'click', function () {
      const target = this.closest(`.dropdown`);

      bootstrap.Dropdown.getOrCreateInstance(target).hide();
    });
  });
});

function setupDropdownFilters() {
  initializePopovers('[data-bs-toggle="popover"]');

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
