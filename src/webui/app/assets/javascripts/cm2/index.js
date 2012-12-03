// This is a manifest file that'll be compiled into codemirror, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require codemirror
//= require codemirror/utils/searchcursor
//= require codemirror/utils/search
//= require codemirror/utils/match-highlighter
//= require codemirror/utils/formatting
//= require cm2/toolbars
//= require cm2/mode/baselibsconf
//= require cm2/mode/prjconf
//= require codemirror/modes/clike.js
//= require codemirror/modes/clojure.js
//= require codemirror/modes/coffeescript.js
//= require codemirror/modes/commonlisp.js
//= require codemirror/modes/css.js
//= require codemirror/modes/diff.js
//= require codemirror/modes/ecl.js
//= require codemirror/modes/erlang.js
//= require codemirror/modes/gfm.js
//= require codemirror/modes/go.js
//= require codemirror/modes/groovy.js
//= require codemirror/modes/haskell.js
//= require codemirror/modes/haxe.js
//= require codemirror/modes/htmlembedded.js
//= require codemirror/modes/htmlmixed.js
//= require codemirror/modes/javascript.js
//= require codemirror/modes/jinja2.js
//= require codemirror/modes/less.js
//= require codemirror/modes/lua.js
//= require codemirror/modes/markdown.js
//= require codemirror/modes/mysql.js
//= require codemirror/modes/ntriples.js
//= require codemirror/modes/ocaml.js
//= require codemirror/modes/pascal.js
//= require codemirror/modes/perl.js
//= require codemirror/modes/php.js
//= require codemirror/modes/pig.js
//= require codemirror/modes/plsql.js
//= require codemirror/modes/properties.js
//= require codemirror/modes/python.js
//= require codemirror/modes/r.js
//= require codemirror/modes/rpm-changes.js
//= require codemirror/modes/rpm-spec.js
//= require codemirror/modes/rst.js
//= require codemirror/modes/ruby.js
//= require codemirror/modes/rust.js
//= require codemirror/modes/scheme.js
//= require codemirror/modes/shell.js
//= require codemirror/modes/sieve.js
//= require codemirror/modes/smalltalk.js
//= require codemirror/modes/smarty.js
//= require codemirror/modes/sparql.js
//= require codemirror/modes/stex.js
//= require codemirror/modes/tiddlywiki.js
//= require codemirror/modes/tiki.js
//= require codemirror/modes/vb.js
//= require codemirror/modes/vbscript.js
//= require codemirror/modes/velocity.js
//= require codemirror/modes/verilog.js
//= require codemirror/modes/xml.js
//= require codemirror/modes/xmlpure.js
//= require codemirror/modes/xquery.js
//= require codemirror/modes/yaml.js


var editors = new Array();

function use_codemirror(id, read_only, mode)
{
    var codeMirrorOptions = {
	lineNumbers: true,
	matchBrackets: true,
	/* onCursorActivity: function(editor) {
	    editor.setLineClass(editor.hlLine, null);
	    editor.hlLine = editor.setLineClass(editor.getCursor().line, "activeline");
	}, */
    }
    if (read_only) {
	codeMirrorOptions['readOnly'] = true;
	codeMirrorOptions['mode'] = mode;
    }
    else {
	codeMirrorOptions['mode'] = mode;
	codeMirrorOptions['addToolBars'] = 0;
	if (mode.length)
	    codeMirrorOptions['fileType'] = mode;
        codeMirrorOptions['extraKeys'] = {"Tab": "defaultTab", "Shift-Tab": "indentLess"};
        codeMirrorOptions['onUpdate'] = function(cm) {if(typeof(cm) != 'undefined') cm.setWidth(cm)};
        codeMirrorOptions['onChange'] = function(cm) {
	    changed=true; 
	    cm.updateHistory(cm); 
	    if (cm.historySize().undo>0)
		$("#save_" + id).removeClass('inactive');
	    else
		$("#save_" + id).addClass('inactive');
	};
        codeMirrorOptions['onCursorActivity'] = function(cm) {cm.getPosition(cm)};
    }

    var textarea = $('#editor_' + id);
    var height = document.getElementById("editor_" + id).offsetHeight;
    
    var editor = CodeMirror.fromTextArea(document.getElementById("editor_" + id), codeMirrorOptions);
    editor.id = id;
    editor.setSize(null, height - 52);
    editor.setSelections(editor)

    if (textarea.data('save-url')) {
	$('#save_' + id).click(function() {
	    data = textarea.data('data');
	    data[data['submit']] = editors[id].getValue();
	    $("#save_" + id).addClass("inactive").addClass("working");
            $.ajax({
		url: textarea.data('save-url'),
		type: (textarea.data('save-method') || 'put'),
		data: data,
		success: function(data, textStatus, xhdr) { $("#save_" + id).removeClass("working"); },
		error: function(xhdr, textStatus,errorThrown) {
		    $("#save_" + id).removeClass("inactive").removeClass("working"); 
		    /* alert("XHR" + xhdr.responseText + " TS " + textStatus); */
		},
            });
        });
    } else {
	$("#save_" + id).hide();
    }
    editors[id] = editor;

    $('#find_' + id).click(function() { editors[id].Find(this); });
    $('#line_' + id).keydown(function(event) { if(event.keyCode==13) { editors[id].gotoLine(this) }});
    $('#search_disable_' + id).click( function() { editors[id].Search(this) } );
}
