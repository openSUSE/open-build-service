function updateArchDisplay(index) { // jshint ignore:line
  var repoKey = $('#rpm' + index + ' .rpmlint_repo_select option:selected').attr('value');

  $('#rpm' + index + ' .rpmlint_arch_select').hide();
  $('#rpm' + index + ' #rpmlint_arch_select_' + repoKey).show();
}

function initBuildResult(index, rpmlint) { // jshint ignore:line
  $(document).on( 'click', '.build-refresh, .rpm-refresh', function(){
    $(this).find('i').addClass('fa-spin');
  });

  $('#build0 .build-refresh').click();

  if (rpmlint) {
    $('#rpm0 .rpm-refresh').click();
    $(document).on('ajax:before', '.rpmlint_repo_select', function(){
      var index = $(this).parents('.form-inline').data('index');
      var architecture = $("select[name='architecture']:visible option:selected").attr('value');

      updateArchDisplay(index);
      $(this).data('params','architecture=' + architecture);
    });

    $(document).on('ajax:before', '.rpmlint_arch_select', function() {
      var repository = $("select[name='repository']:visible option:selected").attr('value');

      $(this).data('params','repository=' + repository);
    });
  }
}
