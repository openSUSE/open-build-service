var editors = new Array();

function use_codemirror(id, read_only, mode) {
  var codeMirrorOptions = {
    lineNumbers: true,
    matchBrackets: false,
    fontSize: '9pt',
    mode: mode
  };
  if (read_only) {
    codeMirrorOptions['readOnly'] = true;
  }
  else {
    codeMirrorOptions['addToolBars'] = 0;
    if (mode.length)
      codeMirrorOptions['mode'] = mode;
    codeMirrorOptions['extraKeys'] = {"Tab": "defaultTab", "Shift-Tab": "indentLess"};
  }

  var textarea = $('#editor_' + id);
  var editor = CodeMirror.fromTextArea(document.getElementById("editor_" + id), codeMirrorOptions);
  editor.id = id;
  if (!read_only) {
    editor.setSelections(editor);

    editor.on('change', function (cm) {
      var changed = true;
      cm.updateHistory(cm);
      if (cm.historySize().undo > 0) {
        $("#save_" + id).removeClass('inactive');
        $("#comment_" + id).prop('disabled', false);
      } else {
        $("#save_" + id).addClass('inactive');
        $("#comment_" + id).prop('disabled', true);
      }
    });
    CodeMirror.signal(editor, 'cursorActivity', editor);

  }

  if (textarea.data('save-url')) {
    $('#save_' + id).click(function () {
      $('#flash-messages').remove();
      var data = textarea.data('data');
      data[data['submit']] = editors[id].getValue();
      data['comment'] = $("#comment_" + id).val();
      $("#save_" + id).addClass("inactive").addClass("working");
      $("#comment_" + id).prop('disabled', true);
      $.ajax({
        url: textarea.data('save-url'),
        type: (textarea.data('save-method') || 'put'),
        data: data,
        success: function (data, textStatus, xhdr) {
          $("#save_" + id).removeClass("working");
          $("#comment_" + id).prop('disabled', true).val('');
          // The filter is necessary because we don't return a flash everywhere atm
          $(data).filter('#flash-messages').insertAfter('#subheader').fadeIn('slow');
        },
        error: function (xhdr, textStatus, errorThrown) {
          $("#save_" + id).removeClass("inactive").removeClass("working");
          $("#comment_" + id).prop('disabled', false);
          // The filter is necessary because we don't return a flash everywhere atm
          $(xhdr.responseText).filter('#flash-messages').insertAfter('#subheader').fadeIn('slow');
        }
      });
    });
  } else {
    $("#save_" + id).hide();
    $("#comment_" + id).hide();
  }
  editors[id] = editor;
}
