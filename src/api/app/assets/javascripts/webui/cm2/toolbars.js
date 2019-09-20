(function(mod) {
	  if (typeof exports == "object" && typeof module == "object") // CommonJS
	    mod(require("../../lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
	    define(["../../lib/codemirror"], mod);
  else // Plain browser env
	    mod(CodeMirror);
})(function(CodeMirror) {
    var cm_instance;
    CodeMirror.defaults.supportedTypes 	= [];
    CodeMirror.defaults.fileType 		= null;
    CodeMirror.defaults.allowedFontSizes 	= [];
    CodeMirror.defaults.fontSize 		= '1em';
    CodeMirror.defineInitHook(function(cm) {
	this.cm = cm;
        this.cm.on('cursorActivity', function(cm) { update_toolbar_position(cm)});
    });

    function prependOption(cm, name, value) {
	this.cm = cm;
	return;
    }

    CodeMirror.defineExtension("prependOption", function(name,value) {
	return new prependOption(this, name, value);
    });

    function setWidth(cm) {
	this.cm = cm;
	if(typeof(this.cm.id) == 'undefined') return;
	var width = '' + String(this.cm.getWrapperElement().offsetWidth) + 'px';
	document.getElementById('top_'+this.cm.id).style.width = width;
	document.getElementById('bottom_'+this.cm.id).style.width = width;
    }

    CodeMirror.defineExtension("setWidth", function() {
	return new setWidth(this);
    });

    function updateHistory(cm) {
	this.cm = cm;
	this.undo = $('#undo_'+this.cm.id);
	this.redo = $('#redo_'+this.cm.id);
	this.cm.historySize().undo>0 ? this.undo.removeClass("disabled") : this.undo.addClass("disabled");
	this.cm.historySize().redo>0 ? this.redo.removeClass("disabled") : this.redo.addClass("disabled");
    }

    CodeMirror.defineExtension("updateHistory", function() {
	return new updateHistory(this);
    });

    function update_toolbar_position(cm) {
	this.cm = cm;
	var position = this.cm.getCursor(true);
	var line = position.line + this.cm.getOption('firstLineNumber');
	if(document.getElementById('ln_'+this.cm.id) != null) document.getElementById('ln_'+this.cm.id).innerHTML = line;
	if(document.getElementById('ch_'+this.cm.id) != null) document.getElementById('ch_'+this.cm.id).innerHTML = position.ch;
	if(document.getElementById('match_'+this.cm.id) != null && document.getElementById('match_'+this.cm.id).value == 'on') {
	    this.cm.matchHighlight("CodeMirror-matchhighlight");
	}
    }

    CodeMirror.defineExtension("getPosition", function() {
	return new getPosition(this);
    });

    function setSelections(cm) {
	this.cm = cm;
	var options = this.cm.getOption('supportedTypes');
	var modeSelector = document.getElementById('mode_'+this.cm.id);
	if(typeof this.cm.getOption('supportedTypes')[0] != 'undefined') {
	    modeSelector.innerHTML = '';
	    for(var i=0;i<options.length;i++) {
		var option = document.createElement('OPTION');
		option.setAttribute('id', options[i].fileType+'_'+this.cm.id);
		option.setAttribute('value', options[i].mode);
		option.innerHTML = options[i].fileType;
		modeSelector.appendChild(option);
	    }
	}
	var selectedType = this.cm.getOption('fileType');
	if(selectedType != null) {
	    modeSelector.value = document.getElementById(selectedType+'_'+this.cm.id).value;
	    this.cm.setOption('mode', modeSelector.value);
	}
	options = this.cm.getOption('allowedFontSizes');
	var fontSelector = document.getElementById('fontsize_'+this.cm.id);
	if(typeof this.cm.getOption('allowedFontSizes')[0] != 'undefined') {
	    fontSelector.innerHTML = '';
	    for(i=0;i<options.length;i++) {
		var option = document.createElement('OPTION');
		option.setAttribute('value', options[i]);
		option.innerHTML = options[i];
		fontSelector.appendChild(option);
	    }
	}
	fontSelector.value = this.cm.getOption('fontSize');
	this.cm.getWrapperElement().style.fontSize = fontSelector.value;
	var tabSelector = document.getElementById('tabsize_'+this.cm.id);
	if(tabSelector != null) tabSelector.value = this.cm.getOption('tabSize');
	var smartOnoff = document.getElementById('smart_'+this.cm.id);
	if(smartOnoff != null) smartOnoff.value = this.cm.getOption('smartIndent') ? 'on' : 'off' ;
    }

    CodeMirror.defineExtension("setSelections", function() {
	return new setSelections(this);
    });

    var cursor;
    var marked = Array();
    var search;
    var replace;
    function Search(cm, elt) {
        var query, begin;

	this.cm = cm;
	elt.value = elt.value == 'on' ? 'off' : 'on' ;
	document.getElementById('find_'+this.cm.id).style.display = 'inline';
	document.getElementById('prenex_'+this.cm.id).style.display = 'none';
	var S = document.getElementById('search_'+this.cm.id);
	var R = document.getElementById('replace_'+this.cm.id);
	if(elt.value == 'on') {
	    S.removeAttribute('disabled');
	    S.style.backgroundColor = '';
	    R.removeAttribute('disabled');
	    R.style.backgroundColor = '';

	    if(this.cm.somethingSelected()) {
		query = this.cm.getSelection();
		S.value = query;
		begin = this.cm.getCursor(true);
	    }
	    else {
		begin = getBegin(cm);
	    }
	}
	else if(elt.value == 'off') {
	    S.setAttribute('disabled', true);
	    S.style.backgroundColor = 'transparent';
	    R.setAttribute('disabled', true);
	    R.style.backgroundColor = 'transparent';
	    S.value = '';
	    R.value = '';
	    for(var i=0; i<marked.length; i++) {
		marked[i].clear();
	    }
	    cursor= null;
	    if(typeof(mark) != 'undefined') mark.clear();
	    marked = [];
	    begin = null;
	}
	elt.blur();
    }

    CodeMirror.defineExtension("Search", function(elt) {
	return new Search(this, elt);
    });

    function Find(cm, elt) {
        var found, mark;

	this.cm = cm;
	var S = document.getElementById('search_'+this.cm.id);
	if(S.disabled) return;
	if(S.value == '') {
	    document.getElementById('search_'+this.cm.id).style.background = '#ffffcc';
	    return;
	}
	this.cm.focus();
	elt.style.display = 'none';
	document.getElementById('prenex_'+this.cm.id).style.display = 'inline';
	query = S.value;
	cursor = this.cm.getSearchCursor(query, begin);
	console.log(cursor);
	found = cursor.findNext();
	var firstFound = cursor;
	begin = null;
	begin = {line:cursor.from().line, ch:cursor.from().ch};
	cursor = this.cm.getSearchCursor(query, {line:0, ch:0});

	for(;;) {
	    found = cursor.findNext();
	    if(found == false) {
		cursor = null;
		break;
	    }
	    if(typeof(cursor.from()) != 'undefined' && typeof(begin) != 'undefined') {
		if(cursor.from().line == begin.line && cursor.from().ch == begin.ch) {
		    mark = this.cm.markText(cursor.from(), cursor.to(), 'CodeMirror-markSelected');
		    marked.push(mark);
		}
		else {
		    mark = this.cm.markText(cursor.from(), cursor.to(), 'CodeMirror-markFound');
		    marked.push(mark);
		}
	    }
	    this.cm.setSelection(firstFound.from(), firstFound.to());
	}
    }

    CodeMirror.defineExtension("Find", function(elt) {
	return new Find(this, elt);
    });

    function Next(cm, elt) {
	this.cm = cm;
	if(cursor == null) {
	    cursor = this.cm.getSearchCursor(query, begin);
	    cursor.findNext();
	}
	if(typeof(mark) != 'undefined') mark.clear();
	var found = cursor.findNext();
	if(found == true) {
	    mark = this.cm.markText(cursor.from(), cursor.to(), 'CodeMirror-markNextPrev');
	    marked.push(mark);
	    this.cm.setSelection(cursor.from(), cursor.to());
	}
	else {
	    cursor = this.cm.getSearchCursor(query, {line:0,ch:0});
	}
	return;
    }

    CodeMirror.defineExtension("Next", function(elt) {
	return new Next(this, elt);
    });

    function Prev(cm, elt) {
	this.cm = cm;
	if(cursor == null) {
	    cursor = this.cm.getSearchCursor(query, begin);
	}
	if(typeof(mark) != 'undefined') mark.clear();
	var found = cursor.findPrevious();
	if(found != false){
	    mark = this.cm.markText(cursor.from(), cursor.to(), 'CodeMirror-markNextPrev');
	    marked.push(mark);
	    this.cm.setSelection(cursor.from(), cursor.to());
	}
	return;
    }

    CodeMirror.defineExtension("Prev", function(elt) {
	return new Prev(this, elt);
    });

    function Replace(cm, elt) {
	this.cm = cm;
	if(cursor == null) {
	    cursor = this.cm.getSearchCursor(query, begin);
	    cursor.findNext();
	}
	var replace = document.getElementById('replace_'+this.cm.id).value;
	cursor.replace(replace);
	if(typeof(mark) != 'undefined') mark.clear();
	found = cursor.findNext();
	mark = this.cm.markText(cursor.from(), cursor.to(), 'CodeMirror-markNextPrev');
	marked.push(mark);
	this.cm.setSelection(cursor.from(), cursor.to());
    }

    CodeMirror.defineExtension("Replace", function(elt) {
	return new Replace(this, elt);
    });

    function ReplaceAll(cm, elt) {
	this.cm = cm;
	cursor = this.cm.getSearchCursor(query, {line:0, ch:0});
	var replace = document.getElementById('replace_'+this.cm.id).value;
	for(;;) {
	    found = cursor.findNext();
	    if(found == false) {
		cursor = null;
		break;
	    }
	    cursor.replace(replace);
	}
    }

    CodeMirror.defineExtension("ReplaceAll", function(elt) {
	return new ReplaceAll(this, elt);
    });

    function Match(cm, elt) {
	this.cm = cm;
	if(elt.innerHTML == 'on') {
	    var position = this.cm.getCursor(false);
	    this.cm.setCursor(position);
	    elt.classList.remove("btn-success");
	    elt.classList.add("btn-danger");
	}
	else {
	    elt.classList.remove("btn-danger");
	    elt.classList.add("btn-success");
	}
	elt.innerHTML  = elt.innerHTML == 'on' ? 'off'   : 'on' ;
    }

    CodeMirror.defineExtension("Match", function(elt) {
	return new Match(this, elt);
    });

    function Undo(cm, elt) {
	this.cm = cm;
	this.cm.undo();
	elt.blur();
    }

    CodeMirror.defineExtension("Undo", function(elt) {
	return new Undo(this, elt);
    });

    function Redo(cm, elt) {
	this.cm = cm;
	this.cm.redo();
	elt.blur();
    }

    CodeMirror.defineExtension("Redo", function(elt) {
	return new Redo(this, elt);
    });

    function updateFontsize(cm, elt) {
	this.cm = cm;
	this.cm.getWrapperElement().style.fontSize = elt.value;
	this.cm.refresh();
	elt.blur();
    }

    CodeMirror.defineExtension("updateFontsize", function(elt) {
	return new updateFontsize(this, elt);
    });

    function updateMode(cm, elt) {
	this.cm = cm;
	this.cm.setOption("mode", elt.value);
	elt.blur();
    }

    CodeMirror.defineExtension("updateMode", function(elt) {
	return new updateMode(this, elt);
    });

    function SmartIndent(cm, elt) {
	this.cm = cm;
	elt.value  = elt.value == 'on' ? 'off'   : 'on' ;
	if(elt.value == 'on') {
	    this.cm.setOption('smartIndent', true);
	    this.cm.setOption('electricChars', true);
	    this.cm.setOption('extraKeys', {"Shift-Tab": "indentLess"});
	}
	else {
	    this.cm.setOption('smartIndent', false);
	    this.cm.setOption('electricChars', false);
	    this.cm.setOption('extraKeys', {"Tab": "defaultTab", "Shift-Tab": "indentLess"});
	}
    }


    CodeMirror.defineExtension("SmartIndent", function(elt) {
	return new SmartIndent(this, elt);
    });

    function autoFormat(cm, elt) {
	this.cm = cm;
	if(this.cm.somethingSelected()) {
	    this.cm.autoFormatRange(this.cm.getCursor(true), this.cm.getCursor(false));
	}
	else {
	    var totalLines = this.cm.lineCount();
	    var totalChars = this.cm.getValue().length;
	    this.cm.autoFormatRange(
		{line: 0, ch: 0},
		{line: totalLines - 1, ch: this.cm.getLine(totalLines - 1).length}
	    );
	}
	elt.blur();
    }

    CodeMirror.defineExtension("autoFormat", function(elt) {
	return new autoFormat(this, elt);
    });

    function updateTabsize(cm, elt) {
	this.cm = cm;
	this.cm.setOption("tabSize", Number(elt.value));
	this.cm.setOption("indentUnit", Number(elt.value));
	elt.blur();
    }

    CodeMirror.defineExtension("updateTabsize", function(elt) {
	return new updateTabsize(this, elt);
    });


    function gotoLine(cm, elt) {
	this.cm = cm;
	this.ln = document.getElementById('line_'+this.cm.id).value - this.cm.getOption('firstLineNumber');
	this.cm.focus();
	this.cm.setCursor(this.ln, 0);
	this.cm.scrollIntoView(null);
	document.getElementById('line_'+this.cm.id).blur();
    }

    CodeMirror.defineExtension("gotoLine", function(elt) {
	return new gotoLine(this, elt);
    });

    function Wrap(cm, elt) {
	this.cm = cm;
	if(elt.innerHTML == 'on') {
	    elt.classList.remove("btn-success");
	    elt.classList.add("btn-danger");
	}
	else {
	    elt.classList.remove("btn-danger");
	    elt.classList.add("btn-success");
	}
	elt.innerHTML = elt.innerHTML == 'on' ? 'off' : 'on' ;
	this.value = elt.innerHTML == 'on' ;
	this.cm.setOption('lineWrapping', this.value);
    }

    CodeMirror.defineExtension("Wrap", function(elt) {
	return new Wrap(this, elt);
    });

    function increase(cm, elt) {
	this.cm = cm;
	this.height = this.cm.getScrollerElement().offsetHeight + 40;
	this.width  = this.cm.getWrapperElement().offsetWidth + 65;
	this.cm.setSize(this.width, this.height);
	document.body.scrollTop += 40;
	elt.blur();
    }

    CodeMirror.defineExtension("increase", function(elt) {
	return new increase(this, elt);
    });

    function decrease(cm, elt) {
	this.cm = cm;
	this.height = this.cm.getScrollerElement().offsetHeight - 40;
	this.width  = this.cm.getWrapperElement().offsetWidth - 69;
	this.cm.setSize(this.width, this.height);
	document.body.scrollTop -= 40;
	elt.blur();
    }

    CodeMirror.defineExtension("decrease", function(elt) {
	return new decrease(this, elt);
    });

    function getBegin(cm) {
	this.cm = cm;
	var info = this.cm.getScrollInfo();
	var lineHeight= Math.round((info.height - 10)/this.cm.lineCount());
	var lineNumber = Math.round((info.y-3)/lineHeight);
	return {line:lineNumber, ch:0};
    }
});
