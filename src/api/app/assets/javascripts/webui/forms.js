$(document).ready(function() {
  // to resolve the filename in the label
  $('input[type="file"].form-control').on('change',function() {
      var forAttribute = $(this).attr("for");
      //get the file name
      var fileName = $(this).val();
      // Most modern browser don't allow JS to access
      // the full path of the file and show e.g. C:\fakepath
      // As this is confusing we only show the filename and strip the path
      fileName = fileName.replace(/^.*[\\\/]/, '');
      //replace the "Choose a file" label
      $(this).next('label[for="' + forAttribute + '"]').html(fileName);
  });
});
