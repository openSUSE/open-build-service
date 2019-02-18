function updateArchDisplay(index) { // jshint ignore:line
  var repoKey = $('#rpm' + index + ' .rpmlint_repo_select option:selected').attr('value');

  $('#rpm' + index + ' .rpmlint_arch_select').hide();
  $('#rpm' + index + ' #rpmlint_arch_select_' + repoKey).show();
}

function rpmlintShowMore(index) { // jshint ignore:line
  var $logContent = $('#rpm' + index + ' .rpmlint-result');
  var $this = $('#rpm' + index + ' .rpm-show-more');
  $this.text('show more');
  $logContent.addClass('max-height');
  $this.addClass('d-none');
  if ($logContent[0].offsetHeight < $logContent[0].scrollHeight) {
    $this.removeClass('d-none');
  }
}

function rpmlintEvents() {
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

  $(document).on('click', '.rpm-show-more', function() {
    var $this = $(this);
    var $logContent = $this.parents('.result').find('.rpmlint-result');

    $logContent.toggleClass('max-height');
    $this.text($logContent.hasClass('max-height') ? 'show more' : 'show less');
  });
}

function requestEvents() {
  $(document).on('click', '.request-tab', function(){
    var $id = $(this).attr('href');

    $($id + ' .build-refresh').click();
    $($id + ' .rpm-refresh').click();
  });
}

function initBuildResult(index, rpmlint) { // jshint ignore:line
  $(document).on('click', '.build-refresh, .rpm-refresh', function(){
    $(this).find('i').addClass('fa-spin');
  });

  $('#build0 .build-refresh').click();
  $('#rpm0 .rpm-refresh').click();

  if (rpmlint) rpmlintEvents();
  if ($('.request-tab').length > 1) { requestEvents(); }
}
