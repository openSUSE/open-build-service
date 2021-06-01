$(function ($) {
  $('.expand-diffs').on('click', function () {
    var forPackage = $(this).data('package');
    var details = $('details.card.details-with-coderay[data-package="' + forPackage + '"]');
    details.attr('open', 'open');
  });

  $('.collapse-diffs').on('click', function () {
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
