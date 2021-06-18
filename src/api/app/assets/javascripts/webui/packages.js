$(function ($) {
  // There are three input fields on the package add file view: filename, url and choose file
  // and only one of them is required.
  // We just set HTML5 required tags on all of them and set to false with JS
  // when one of them is set.
  var $inputs = $('.package-add-file input');
  $inputs.on('change', function () {
    var otherInputWithValueExists = $inputs.not(this).filter(function() {
        return !!this.value;
    }).length > 0;

    if(!otherInputWithValueExists) {
      $inputs.prop('required', !$(this).val().length);
    }
  });

  $('body').on('click', '.expand-diffs', function () {
    var forPackage = $(this).data('package');
    var details = $('details.card.details-with-coderay[data-package="' + forPackage + '"]');
    details.attr('open', 'open');
  });

  $('body').on('click', '.collapse-diffs', function () {
    var forPackage = $(this).data('package');
    var details = $('details.card.details-with-coderay[data-package="' + forPackage + '"]');
    details.attr('open', null);
  });
});

$(document).ready(function() {
  $('.btn-more').click(function() {
    var moreInfo = $('.more_info');
    moreInfo.toggleClass('d-none');
    $(this).text(moreInfo.hasClass('d-none') ? 'more info' : 'less info');
  });
});
