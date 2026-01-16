/* exported updateRpmLintArchitectures */

function updateRpmLintArchitectures() {
  $('.rpmlint_arch_select').hide();
  $('#rpmlint_arch_select_' + $('#rpmlint_repo_select option:selected').attr('value')).show();
  updateRpmLintLog();
}


function updateRpmLintLog() {
  var repoKey = $('#rpmlint_repo_select option:selected').attr('value');
  var ajaxDataShow = {};
  ajaxDataShow.repository = $('#rpmlint_repo_select option:selected').html();
  ajaxDataShow.architecture = $('#rpmlint_arch_select_' + repoKey + ' option:selected').attr('value');
  ajaxDataShow.renderChart = true;
  $.ajax({
    url: '/package/rpmlint_log/' + $('#rpmlint-log').data('project') + '/' + $('#rpmlint-log').data('package'),
    data: ajaxDataShow,
    success: function (data) {
      $('.rpmlint-result').html(data);
    },
    error: function (jqXHR, textStatus, errorThrown) {
      $('.rpmlint-result').html('<p class="error">Error loading rpmlint log (' + errorThrown + ')</p>');
    }
  });
}

$(document).on('click', '.js-accordion-proxy', function(e) {
  e.preventDefault();
  e.stopPropagation();

  var targetId = $(this).data('target');
  var targetEl = document.getElementById(targetId);

  if (targetEl) {
    var collapseTargetSelector = targetEl.getAttribute('data-bs-target');
    var collapseEl = document.querySelector(collapseTargetSelector);
    if (collapseEl) {
      var bsCollapse = bootstrap.Collapse.getOrCreateInstance(collapseEl);
      bsCollapse.toggle();
      targetEl.classList.toggle('collapsed');
    }
  }
});

$(document).on('mouseenter', '.lint-description', function() {
  $(this).tooltip({
    container: 'body',
    trigger: 'hover'
  }).tooltip('show');
});
