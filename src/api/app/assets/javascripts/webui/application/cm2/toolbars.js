(function(mod) {
	  if (typeof exports == "object" && typeof module == "object") // CommonJS
	    mod(require("../../lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
	    define(["../../lib/codemirror"], mod);
  else // Plain browser env
	    mod(CodeMirror);
})(function(CodeMirror) {
    var cm_instance;
    CodeMirror.defaults.addToolBars 	= 0;
    CodeMirror.defaults.supportedTypes 	= [];
    CodeMirror.defaults.fileType 		= null;
    CodeMirror.defaults.allowedFontSizes 	= [];
    CodeMirror.defaults.fontSize 		= '9pt';
    CodeMirror.defineInitHook(function(cm) {
	this.cm = cm;
	var bartype = this.cm.getOption("addToolBars");
        this.cm.on('cursorActivity', function(cm) { update_toolbar_position(cm)});
	if(bartype > 0) this.cm.buildToolBars(bartype);
    });
    
    function buildToolBars(cm, bartype) {
	if(bartype == 0) return;
	this.cm = cm;
	if(typeof(cm_instance) == 'undefined') {
	    cm_instance = new Array();
	    var cm_counter = 0;
	}
	else {
	    cm_counter++;	
	}
	cm_instance[cm_counter] = this.cm;
	this.cm.id = cm_counter;
	var onUpdateValue = this.cm.getOption('onUpdate');
	this.cm.setOption('onUpdate', '');
	var slot1 = bartype == 1 ? '' : searchSpan(this.cm.id) ;
	var slot2 = bartype == 1 ? sizeSpan(this.cm.id) : positionSpan(this.cm.id) ;
	var wrapper = this.cm.getWrapperElement();
	var container = wrapper.parentNode;
	this.cm.topBar = document.createElement("DIV");
	this.cm.topBar.setAttribute("id", "top_"+this.cm.id);
	container.insertBefore(this.cm.topBar, wrapper);
	this.cm.topBar.innerHTML = buildtop(slot1, this.cm.id);
	this.cm.bottomBar = document.createElement("DIV");
	this.cm.bottomBar.setAttribute("id", "bottom_"+this.cm.id);
	container.insertBefore(this.cm.bottomBar, wrapper.nextSibling);
	this.cm.bottomBar.innerHTML = buildbottom(slot2, this.cm.id);
	this.cm.width = this.cm.getWrapperElement().offsetWidth;
	this.cm.bottomBar.style.width = '' + String(this.cm.width) + 'px';
	this.cm.topBar.style.width =    '' + String(this.cm.width) + 'px';
	//this.cm.setOption('onUpdate', onUpdateValue);
	//this.cm.prependOption('onUpdate', setWidth);
	this.cm.prependOption('onChange', updateHistory);
	//this.cm.prependOption('onCursorActivity', getPosition);
	this.cm.setSelections();
    }

    CodeMirror.defineExtension("buildToolBars", function(bartype) {
	return new buildToolBars(this, bartype);
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
	document.getElementById('undo_'+this.cm.id).style.backgroundColor = this.cm.historySize().undo>0 ? '' : 'transparent' ;
	document.getElementById('redo_'+this.cm.id).style.backgroundColor = this.cm.historySize().redo>0 ? '' : 'transparent' ;
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
	if(document.getElementById('match_'+this.cm.id).value == 'on') {
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
	if(elt.value == 'on') {
	    var position = this.cm.getCursor(false);
	    this.cm.setCursor(position);
	}
	elt.value  = elt.value == 'on' ? 'off'   : 'on' ;
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
	elt.value = elt.value == 'on' ? 'off' : 'on' ;
	this.value = elt.value == 'on' ;
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
    
    function buildtop(slot, id) {  
	var topbar = ''+
	    '<div class="toolbar">'+
	    slot+
	    '<span style="float:left;">'+
	    '<span class="text">matching:</span>'+
	    '<input type="button" id="match_'+id+'" class="tools buttons small" value="off" onclick="cm_instance['+id+'].Match(this);"/>'+
	    '</span>'+
	    '<span style="float:right;">'+
	    '<input type="button" id="undo_'+id+'" value="undo" class="tools buttons undo" style="background:transparent;" onclick="cm_instance['+id+'].Undo(this);"/>'+
	    '<input type="button" id="redo_'+id+'" value="redo" class="tools buttons redo" style="background:transparent;" onclick="cm_instance['+id+'].Redo(this);"/>'+
	    '<select class="tools select" id="fontsize_'+id+'" onchange="cm_instance['+id+'].updateFontsize(this)">'+
	    '<option value="8pt" >	8pt </option>'+
	    '<option value="9pt" >	9pt </option>'+
	    '<option value="10pt" >	10pt</option>'+
	    '<option value="11pt" >	11pt</option>'+
	    '<option value="12pt" >	12pt</option>'+
	    '<option value="14pt" >	14pt</option>'+	
	    '</select>'+
	    '<select class="tools select" id="mode_'+id+'" onchange="cm_instance['+id+'].updateMode(this)">'+
	    '<option id="css_'+id+'"  value="css" >				css </option>'+
	    '<option id="html_'+id+'" value="htmlmixed">			html</option>'+
	    '<option id="js_'+id+'"   value="javascript">			js  </option>'+
	    '<option id="php_'+id+'"  value="application/x-httpd-php-open">	php </option>'+
	    '<option id="mysql_'+id+'"value="mysql" >			mysql </option>'+
	    '<option id="xml_'+id+'"  value="xml" >				xml </option>'+
	    '<option id="x_'+id+'"    value="" >				--- </option>'+				
	    '</select>'+
	    '</span>'+
	    '</div>';
	return topbar;
    }

    function buildbottom(slot, id) {
	var bottombar = ''+
	    '<div class="toolbar">'+
	    slot +
	    '<span style="float:right;">'+
	    '<span class="text">line:</span>'+
	    '<input type="text" id="line_'+id+'" class="tools inputs" autocomplete="off" style="width:30px;"onkeydown="if(event.keyCode==13){cm_instance['+id+'].gotoLine(this);}" />'+
	    '<input type="button" class="tools buttons small" value="go" onclick="cm_instance['+id+'].gotoLine(this);" />'+
	    '&nbsp;&nbsp;'+
	    '<span class="text">line wrapping:</span>'+
	    '<input type="button" class="tools buttons small" value="off" onclick="cm_instance['+id+'].Wrap(this)" />'+
	    '</span>'+ 
	    '</div>';
	return bottombar;
    }

    function searchSpan(id) {
	var searchHTML = ''+
	    '<span style="float:left;">'+
	    '<span class="text">search:</span>'+
	    '<input type="button" class="tools buttons small" value="off" onclick="cm_instance['+id+'].Search(this)" />'+ 
	    '<input disabled type="text"  class="tools inputs" style="background:transparent" id="search_'+id+'" autocomplete="off" placeholder="type or select" onkeydown="this.removeAttribute(\'style\');" />'+
	    
	'<span class="prenex" id="prenex_'+id+'" style="display:none;">'+
	    '<input type="button" class="tools buttons prev" value="&#9668" id="prev_'+id+'" onclick="cm_instance['+id+'].Prev(this)" />'+
	    '<input type="button" class="tools buttons next" value="&#9658;" id="next_'+id+'" onclick="cm_instance['+id+'].Next(this)" />'+
	    '</span>'+
	    
	'<input type="button" class="tools buttons small" style="width:36px;" value="find" id="find_'+id+'" onclick="cm_instance['+id+'].Find(this)" />'+
	    '&nbsp;&nbsp;'+
	    '<span class="text">replace:</span>'+
	    '<input disabled type="text" class="tools inputs" style="background:transparent" id="replace_'+id+'"  autocomplete="off" />'+
	    '<input type="button" class="tools buttons medium" value="replace" onclick="cm_instance['+id+'].Replace(this);" />'+
	    '<input type="button" class="tools buttons medium" value="replace all" onclick="cm_instance['+id+'].ReplaceAll(this);" />'+
	    '&nbsp;&nbsp;&nbsp;'+
	    '</span>';
	return searchHTML;
    }
    
    function sizeSpan(id) {			
	var sizeHTML = ''+
	    '<span style="float:left;">'+
	    '<input type="button" class="tools buttons large" value="increase size" onclick="cm_instance['+id+'].increase(this);" />'+
	    '<input type="button" class="tools buttons large" value="decrease size" onclick="cm_instance['+id+'].decrease(this);" />'+
	    '</span>';
	return sizeHTML;
    }
    
    function positionSpan(id) {
	var positionHTML = ''+
	    '<span style="float:left;">'+
	    '<span class="text">position</span>'+
	    '&nbsp;&nbsp;'+
	    '<span class="text">line:</span>'+
	    '<span id="ln_'+id+'" class="text" style="display:inline-block;width:30px;">0</span>'+
	    '<span class="text">char:</span>'+
	    '<span id="ch_'+id+'" class="text" style="display:inline-block;width:30px;">0</span>'+
	    '<span class="text">auto-indent:</span>'+
	    '<input type="button" class="tools buttons small" value="off" onclick="cm_instance['+id+'].SmartIndent(this)" />'+
	    '<input type="button" class="tools buttons" style="width:75px;" value="auto-format" onclick="cm_instance['+id+'].autoFormat(this)" />'+	
	    '&nbsp;&nbsp;'+
	    '<span class="text">tab size:</span>'+
	    '<select class="tools select" style="min-width:30px;" id="tabsize_'+id+'" onchange="cm_instance['+id+'].updateTabsize(this)">'+
	    '<option value="2"> 2 </option>'+
	    '<option value="3"> 3 </option>'+
	    '<option value="4"> 4 </option>'+
	    '<option value="5"> 5 </option>'+
	    '<option value="6"> 6 </option>'+
	    '<option value="7"> 7 </option>'+
	    '<option value="8"> 8 </option>'+				
	    '</select>'+
	    '</span>';
	return positionHTML;
    }
});
