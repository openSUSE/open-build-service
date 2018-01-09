$(document).ready(function(){
  $('#upload-jobs').DataTable({
    order: [0, 'desc'],
    pageLength: 25,
  });
});
