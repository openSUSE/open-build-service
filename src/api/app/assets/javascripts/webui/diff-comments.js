$(document).ready(function() {
  $('.line-new-comment').on('click', function(){
    var lineNumber = $(this).data('id')
    var requestNumber = $(this).data('request-number')
    var actionId = $(this).data('action-id')
    var url = '/request/' + requestNumber + '/request_action/' + actionId + '/inline_comment/' + lineNumber

    $.ajax({
      url: url
    });
  })
})