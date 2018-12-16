function setSpinnersForFlags() { // jshint ignore:line
  $(document).on('click', '.popover_flag_action', function() {
    var flag = $(this).data('flag-id');
    var icon = $('div[id="' + flag + '"] a');
    icon.addClass('d-none');
    icon.next().removeClass('d-none');
    $('.popover').popover('hide');
  });
}

function setRepoCheckbox() { // jshint ignore:line
  $('.repocheckbox').click(function() {
    var id = $(this).attr('id');
    var $form;
    if ($(this).is(':checked')) {
      $form = $('#' + id + '_create');
    } else {
      $form = $('#' + id + '_destroy');
    }
    $form.submit();
  });
}

function takeOverData(target, source, field) {
  target.data(field, source.data(field));
}

function prepareFlagPopover() {
  var option1, option2;
  if ($(this).data('user-set')) {
    option1 = '.flag-set-' + $(this).data('status');
    option2 = '.flag-remove-' + $(this).data('default');
  } else {
    option1 = '.flag-set-disable';
    option2 = '.flag-set-enable';
  }

  var clone = $('<div/>');
  takeOverData(clone, $(this), 'repository');
  takeOverData(clone, $(this), 'architecture');
  takeOverData(clone, $(this), 'flag');

  clone.append($(option1).html());
  clone.append('<div class=".pt-2"/>');
  clone.append($(option2).html());
  return clone;
}

function setupFlagPopup() {
  $('.flag-popup').popover({
    trigger: 'click',
    html: true,
    content: prepareFlagPopover
  });
  $(document).on('click', '.popover_flag_action', function(e) {
    data = {
      repository: $(this).parent().data('repository'),
      flag: $(this).parent().data('flag'),
      architecture: $(this).parent().data('architecture'),
      command: $(this).data('cmd')
    };
    $.ajax({
      method: 'POST',
      url: $('#flag-popover-container').data('url'),
      data: data
    });
    e.preventDefault();
  });
}
