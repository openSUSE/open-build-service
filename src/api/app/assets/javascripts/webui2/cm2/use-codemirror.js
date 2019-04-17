var editors = new Array();

var unstaged = false;

// Show a dialog when there are unsaved changes (redo or undo) and the user is about to leave the page
window.onbeforeunload = function() {
  if (unstaged) {
    return true;
  }
}

function cm_mark_diff_lines() {
  // as we can't use css to mark parents we use javascript to propagate diff lines
  $('.cm-positive').parents('.CodeMirror-line').addClass('CodeMirror-positive-line');
  $('.cm-negative').parents('.CodeMirror-line').addClass('CodeMirror-negative-line');
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

  cm_mark_diff_lines();
  editor.on('scroll', cm_mark_diff_lines);

  if (!read_only) {
    editor.setSelections(editor);

    editor.on('change', function (cm) {
      var undoChanged = cm.historySize().undo > 0,
          redoChanged = cm.historySize().redo > 0;

      cm.updateHistory(cm);

      unstaged = undoChanged || redoChanged;
      $("#undo_" + id).prop('disabled', !undoChanged);
      $("#redo_" + id).prop('disabled', !redoChanged);
      $("#save_" + id).prop('disabled', !undoChanged);
    });
    CodeMirror.signal(editor, 'cursorActivity', editor);

  }

  if (textarea.data('save-url')) {
    $('#save_' + id).click(function () {
      var data = textarea.data('data');
      data[data['submit']] = editors[id].getValue();
      $("#loading_" + id).attr('disabled', true).removeClass("d-none");
      $.ajax({
        url: textarea.data('save-url'),
        type: (textarea.data('save-method') || 'put'),
        data: data,
        success: function (data, textStatus, xhdr) {
          $("#loading_" + id).addClass("d-none");
          // The filter is necessary because we don't return a flash everywhere atm
          $("#flash").show().html(data);
          unstaged = false;
          $("#undo_" + id).prop('disabled', true);
          $("#redo_" + id).prop('disabled', true);
          $("#save_" + id).prop('disabled', true);
        },
        error: function (xhdr, textStatus, errorThrown) {
          $("#loading_" + id).removeAttr('disabled').addClass("d-none");
          // The filter is necessary because we don't return a flash everywhere atm
          $("#flash").show().html(xhdr.responseText);
          unstaged = true;
        }
      });
    });
  } else {
    $("#save_" + id).hide();
  }
  editors[id] = editor;
}
