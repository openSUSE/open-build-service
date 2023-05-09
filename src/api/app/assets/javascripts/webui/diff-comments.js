$(document).ready(function() {
  $('.line-new-comment').on('click', function(){
    console.log('diff comments')
    var id = $(this).attr('id')
    console.log(id)
  })
})