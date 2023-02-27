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
  $('.btn-more').click(function() {
    var moreInfo = $('.more_info');
    moreInfo.toggleClass('d-none');
    $(this).text(moreInfo.hasClass('d-none') ? 'more info' : 'less info');
  });
});
