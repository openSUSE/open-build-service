var editors = new Array();

var unstaged = false;

window.onbeforeunload = function() {
  if (unstaged) {
    return true;
  }
}

function use_codemirror(id, read_only, mode) {
  var codeMirrorOptions = {
    lineNumbers: true,
    matchBrackets: false,
    fontSize: '1em',
    mode: mode,
    theme: "bootstrap"
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
      if (cm.historySize().undo > 0 || cm.historySize().redo > 0) {
        $("#save_" + id).removeClass('disabled');
        unstaged = true;
      }
      else {
        $("#save_" + id).addClass('disabled');
        unstaged = false;
      }
    });
    CodeMirror.signal(editor, 'cursorActivity', editor);

  }

  if (textarea.data('save-url')) {
    $('#save_' + id).click(function () {
      var data = textarea.data('data');
      data[data['submit']] = editors[id].getValue();
      $("#loading_" + id).addClass("disabled").removeClass("d-none");
      $.ajax({
        url: textarea.data('save-url'),
        type: (textarea.data('save-method') || 'put'),
        data: data,
        success: function (data, textStatus, xhdr) {
          $("#loading_" + id).addClass("d-none");
          // The filter is necessary because we don't return a flash everywhere atm
          $("#flash").show().html(data);
          unstaged = false;
          $("#save_" + id).addClass('disabled');
        },
        error: function (xhdr, textStatus, errorThrown) {
          $("#loading_" + id).removeClass("disabled").addClass("d-none");
          // The filter is necessary because we don't return a flash everywhere atm
          $("#flash").show().html(xhdr.responseText);
          unstaged = true;
          $("#save_" + id).removeClass('disabled');
        }
      });
    });
  } else {
    $("#save_" + id).hide();
  }
  editors[id] = editor;
}
