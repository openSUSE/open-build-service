$(document).ready(function(){
  var first_column_width = $('#monitor-wrapper table tr > td:first-child').width();

  $('#monitor-wrapper table').css({ 'margin-left': first_column_width });
  $.each($('#monitor-wrapper table tr'), function(i, row) {
    $(row).css({ 'height' : $(row).height() });
  });
  $('#monitor-wrapper table tr > td:first-child').css({ 'background' : '#FFFFFF' });
  $('#monitor-wrapper table tr > td:first-child, #monitor-wrapper table tr > th:first-child').css({
    'position' : 'absolute',
    'width': first_column_width,
    'left': '10px',
    'display': 'inline-block'
  });
});
