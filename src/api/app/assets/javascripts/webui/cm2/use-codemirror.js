var editors = new Array();

var unstaged = false;

// Show a dialog when there are unsaved changes (redo or undo) and the user is about to leave the page
window.onbeforeunload = function() {
  if (unstaged) {
    return true;
  }
}

function cmMarkDiffLines(id) {
  // as we can't use css to mark parents we use javascript to propagate diff lines
  $('#revision_details_' + id + ' .cm-positive').parents('.CodeMirror-line').addClass('CodeMirror-positive-line');
  $('#revision_details_' + id + ' .cm-negative').parents('.CodeMirror-line').addClass('CodeMirror-negative-line');
}

function use_codemirror(id, read_only, mode, big_editor) {
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
    if (mode.length) {
      codeMirrorOptions['mode'] = mode;
    }
    codeMirrorOptions['extraKeys'] = {
        // Insert spaces instead of a tab
        "Tab": function(cm) {
            var spaces = '';
            var indentUnit = cm.getOption('indentUnit');
            for (var i = 0; i < indentUnit; i++) {
                spaces += ' ';
            }
            cm.replaceSelection(spaces);
        },
        "Shift-Tab": "indentLess"
    };
  }

  var textarea = $('#editor_' + id);
  var editor = CodeMirror.fromTextArea(document.getElementById("editor_" + id), codeMirrorOptions);
  editor.id = id;
  if (big_editor) {
    $(editor.getWrapperElement()).addClass('big-editor');
    editor.refresh();
  }

  cmMarkDiffLines(id);
  editor.on('scroll', function() { cmMarkDiffLines(id); });

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
      $("#comment_" + id).prop('disabled', !undoChanged);
    });
    CodeMirror.signal(editor, 'cursorActivity', editor);

  }

  if (textarea.data('save-url')) {
    $('#save_' + id).click(function () {
      var data = textarea.data('data');
      data[data['submit']] = editors[id].getValue();
      data['comment'] = $("#comment_" + id).val();
      $(this).prop('disabled', true);
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
          $("#comment_" + id).prop('disabled', true);
          $("#comment_" + id).val('');
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
    $("#comment_" + id).hide();
  }
  editors[id] = editor;
}
