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
