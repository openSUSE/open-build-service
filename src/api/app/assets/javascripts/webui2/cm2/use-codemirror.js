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
      if (cm.historySize().undo > 0)
        $("#save_" + id).removeClass('inactive');
      else
        $("#save_" + id).addClass('inactive');
    });
    CodeMirror.signal(editor, 'cursorActivity', editor);

  }

  if (textarea.data('save-url')) {
    $('#save_' + id).click(function () {
      var data = textarea.data('data');
      data[data['submit']] = editors[id].getValue();
      $("#save_" + id).addClass("inactive").addClass("working");
      $.ajax({
        url: textarea.data('save-url'),
        type: (textarea.data('save-method') || 'put'),
        data: data,
        success: function (data, textStatus, xhdr) {
          $("#save_" + id).removeClass("working");
          // The filter is necessary because we don't return a flash everywhere atm
          $("#flash").show().html(data);
        },
        error: function (xhdr, textStatus, errorThrown) {
          $("#save_" + id).removeClass("inactive").removeClass("working");
          // The filter is necessary because we don't return a flash everywhere atm
          $("#flash").show().html(xhdr.responseText);
        }
      });
    });
  } else {
    $("#save_" + id).hide();
  }
  editors[id] = editor;
}
