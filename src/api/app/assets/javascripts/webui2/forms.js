$(document).ready(function() {
  // to resolve the filename in the label
  $('.custom-file-input').on('change',function() {
      //get the file name
      var fileName = $(this).val();
      //replace the "Choose a file" label
      $(this).next('.custom-file-label').html(fileName);
  });
});
