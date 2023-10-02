function setSpinnersForFlags() { // jshint ignore:line
  $(document).on('click', '.popover_flag_action', function() {
    var flag = $(this).data('flag-id');
    var icon = $('div[id="' + flag + '"] a');
    icon.addClass('d-none');
    icon.next().removeClass('d-none');
    var popoverList = [].slice.call(document.querySelectorAll('.flag-popup'));
    popoverList.map(function (popover) {
      bootstrap.Popover.getInstance(popover).hide();
    });
  });
}

function takeOverData(target, source, field) {
  target.data(field, source.data(field));
}

function prepareFlagPopover(element) {
  var option1, option2;
  if ($(element).data('user-set')) {
    option1 = '.flag-set-' + $(element).data('status');
    option2 = '.flag-remove-' + $(element).data('default');
  } else {
    option1 = '.flag-set-disable';
    option2 = '.flag-set-enable';
  }

  var clone = $('<div/>');
  takeOverData(clone, $(element), 'repository');
  takeOverData(clone, $(element), 'architecture');
  takeOverData(clone, $(element), 'flag');

  clone.append($(option1).html());
  clone.append('<div class="pt-2"/>');
  clone.append($(option2).html());
  return clone;
}

function initializeFlagPopovers(cssSelector) {
  initializePopovers(cssSelector, { trigger: 'click', html: true, content: prepareFlagPopover }); // jshint ignore:line
}

function replaceFlagTable(data, flagType) {
  $('#flag_table_' + flagType).html(data);
  initializeFlagPopovers('#flag_table_' + flagType + ' .flag-popup');
}

function setupFlagPopup() { // jshint ignore:line
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
