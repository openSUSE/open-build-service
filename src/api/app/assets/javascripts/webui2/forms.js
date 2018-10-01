$(document).ready(function() {
  // to resolve the filename in the label
  $('.custom-file-input').on('change',function() {
      //get the file name
      var fileName = $(this).val();
      // Most modern browser don't allow JS to access
      // the full path of the file and show e.g. C:\fakepath
      // As this is confusing we only show the filename and strip the path
      fileName = fileName.replace(/^.*[\\\/]/, '');
      //replace the "Choose a file" label
      $(this).next('.custom-file-label').html(fileName);
  });
});
