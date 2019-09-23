// eslint-disable-next-line no-unused-vars
function setSpinnersForFlags() {
  $(document).on('click', '.popover_flag_action', function() {
    var flag = $(this).data('flag-id');
    var icon = $('div[id="' + flag + '"] a');
    icon.addClass('d-none');
    icon.next().removeClass('d-none');
    $('.popover').popover('hide');
  });
}

// eslint-disable-next-line no-unused-vars
function setRepoCheckbox() {
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
  clone.append('<div class="pt-2"/>');
  clone.append($(option2).html());
  return clone;
}

function initializeFlagPopovers(cssSelector) {
  initializePopovers(cssSelector, { trigger: 'click', html: true, content: prepareFlagPopover });
}

function replaceFlagTable(data, flagType) {
  $('#flag_table_' + flagType).html(data);
  initializeFlagPopovers('#flag_table_' + flagType + ' .flag-popup');
}

// eslint-disable-next-line no-unused-vars
function setupFlagPopup() {
  ['build', 'useforbuild', 'debuginfo', 'publish'].forEach(function(flagType) {
    initializeFlagPopovers('#flag_table_' + flagType + ' .flag-popup');
  });

  $(document).on('click', '.popover_flag_action', function(e) {
    var flagType = $(this).parent().data('flag');
    var data = {
      repository: $(this).parent().data('repository'),
      flag: flagType,
      architecture: $(this).parent().data('architecture'),
      command: $(this).data('cmd')
    };
    $('#flag_table_' + flagType + ' .current_flag_state').addClass('d-none');
    $('#flag_table_' + flagType + ' .fa-spinner').removeClass('d-none');
    $.ajax({
      method: 'POST',
      url: $('#flag-popover-container').data('url'),
      data: data,
      success: function(data) {
        replaceFlagTable(data, flagType);
      }
    });
    e.preventDefault();
  });
}
