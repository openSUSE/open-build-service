$(function ($) {
  $('details.details-with-codemirror').on('click', function () {
    var editor = $(this).find('.CodeMirror')[0].CodeMirror;
    window.setTimeout(function() {
      editor.refresh();
    },1);
  });

  $('.expand-diffs').on('click', function () {
    var forPackage = $(this).data('package');
    var details = $('details.card.details-with-codemirror[data-package="' + forPackage + '"]');
    details.attr('open', 'open');
    details.find('.CodeMirror').each(function(){
      $(this)[0].CodeMirror.refresh();
    });
  });

  $('.collapse-diffs').on('click', function () {
    var forPackage = $(this).data('package');
    var details = $('details.card.details-with-codemirror[data-package="' + forPackage + '"]');
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
