/* Demonstration of embedding CodeMirror in a bigger application. The
* interface defined here is a mess of prompts and confirms, and
* should probably not be used in a real project.
*/
//var CodeMirrorUI = Class.create();

function CodeMirrorUI(place, options, mirrorOptions) {
  this.initialize(place, options, mirrorOptions);
}

CodeMirrorUI.prototype = {

  initialize: function(textarea, options, mirrorOptions) {
    var defaultOptions = {
      searchMode: 'popup', // other options are 'inline' and 'dialog'.  The 'dialog' option needs work.
      imagePath: '../images/silk',
      path: 'js',
      buttons: ['search', 'undo', 'redo', 'jump', 'reindentSelection', 'reindent','about'],
      saveCallback: function() {},
    }
    this.textarea = textarea
    this.options = options;
    this.setDefaults(this.options, defaultOptions);

    this.buttonDefs = {
      'save': ["Save", "save", this.options.imagePath + "/page_save.png", this.save],
      'search': ["Search/Replace", "find_replace_popup", this.options.imagePath + "/find.png", this.find_replace_popup],
      'searchClose': ["Close", "find_replace_popup_close", this.options.imagePath + "/cancel.png", this.find_replace_popup_close],
      'searchDialog': ["Search/Replace", "find_replace_window", this.options.imagePath + "/find.png", this.find_replace_window],
      'undo': ["Undo", "undo", this.options.imagePath + "/arrow_undo.png", this.undo],
      'redo': ["Redo", "redo", this.options.imagePath + "/arrow_redo.png", this.redo],
      'jump': ["Jump to line #", "jump", this.options.imagePath + "/page_go.png", this.jump],
      'reindentSelection': ["Reformat selection", "reindentSelect", this.options.imagePath + "/text_indent.png", this.reindentSelection],
      'reindent': ["Reformat whole document", "reindent", this.options.imagePath + "/page_refresh.png", this.reindent],
      'about': ["About CodeMirror-UI", "about", this.options.imagePath + "/help.png", this.about]
    };

    //place = CodeMirror.replace(place)

    this.home = document.createElement("div");
    this.textarea.parentNode.insertBefore(this.home, this.textarea);
    /*if (place.appendChild)
     place.appendChild(this.home);
     else
     place(this.home);
     */
    this.self = this;

    var onChange = this.editorChanged.bind(this);
    // preserve custom onChance handler
    if (mirrorOptions.onChange) {
        mirrorOptions.onChange = function() {
            mirrorOptions.onChange();
            onChange();
        }
    } else {
        mirrorOptions.onChange = onChange;
    }
    mir = CodeMirror.fromTextArea(this.textarea, mirrorOptions);
    //console.log(mir);
    this.mirror = mir;

    this.initButtons();

    //this.initWordWrapControl(); // CodeMirror v2 does not support word wrapping

    if (this.options.searchMode == 'inline') {
      this.initFindControl();
    } else if (this.options.searchMode == 'popup') {
      this.initPopupFindControl();
    }

    if (this.saveButton) this.addClass(this.saveButton,'inactive');
    if (this.undoButton) this.addClass(this.undoButton,'inactive');
    if (this.redoButton) this.addClass(this.redoButton,'inactive');	
  },
  setDefaults: function(object, defaults) {
    for (var option in defaults) {
      if (!object.hasOwnProperty(option))
        object[option] = defaults[option];
    }
  },
  toTextArea: function() {
    this.home.parentNode.removeChild(this.home);
    this.mirror.toTextArea();
  },
  initButtons: function() {
    this.buttonFrame = document.createElement("div");
    this.buttonFrame.className = "codemirror-ui-clearfix codemirror-ui-button-frame";
    this.home.appendChild(this.buttonFrame);
    for (var i = 0; i < this.options.buttons.length; i++) {
      var buttonId = this.options.buttons[i];
      var buttonDef = this.buttonDefs[buttonId];
      this.addButton(buttonDef[0], buttonDef[1], buttonDef[2], buttonDef[3], this.buttonFrame);
    }

    //this.makeButton("Search", "search");
    //this.makeButton("Replace", "replace");
    //this.makeButton("Current line", "line");
    //this.makeButton("Jump to line", "jump");
    //this.makeButton("Insert constructor", "macro");
    //this.makeButton("Indent all", "reindent");
  },
  /*
   * This is left over from the MirrorFrame demo.
   * Get rid of it quick.
   */
  /*
   makeButton : function(name, action){
   var button = document.createElement("input");
   button.type = "button";
   button.value = name;
   this.home.appendChild(button);
   button.onclick = function(){
   self[action].call(self);
   };
   },
   */
  createFindBar: function() {
    var findBar = document.createElement("div");
    findBar.className = "codemirror-ui-find-bar";

    this.findString = document.createElement("input");
    this.findString.type = "text";
    this.findString.size = 8;

    this.findButton = document.createElement("input");
    this.findButton.type = "button";
    this.findButton.value = "Find";
    this.findButton.onclick = function(){this.find()}.bind(this);

    this.connect(this.findString, "keyup", function(e){ 
      var code = e.keyCode;
      if (code == 13){
        this.find(this.mirror.getCursor(false)) 
      }else{
        if(!this.findString.value == ""){
          this.find(this.mirror.getCursor(true))
        } 
      }
      this.findString.focus();
      
    }.bind(this) );

    var regLabel = document.createElement("label");
    regLabel.title = "Regular Expressions"
    this.regex = document.createElement("input");
    this.regex.type = "checkbox"
    this.regex.className = "codemirror-ui-checkbox"
    regLabel.appendChild(this.regex);
    regLabel.appendChild(document.createTextNode("RegEx"));

    var caseLabel = document.createElement("label");
    caseLabel.title = "Case Sensitive"
    this.caseSensitive = document.createElement("input");
    this.caseSensitive.type = "checkbox"
    this.caseSensitive.className = "codemirror-ui-checkbox"
    caseLabel.appendChild(this.caseSensitive);
    caseLabel.appendChild(document.createTextNode("A/a"));

    this.replaceString = document.createElement("input");
    this.replaceString.type = "text";
    this.replaceString.size = 8;

    this.connect(this.replaceString, "keyup", function(e){ 
      var code = e.keyCode;
      if (code == 13){
        this.replace()
      }
    }.bind(this) );

    this.replaceButton = document.createElement("input");
    this.replaceButton.type = "button";
    this.replaceButton.value = "Replace";
    this.replaceButton.onclick = this.replace.bind(this);

    var replaceAllLabel = document.createElement("label");
    replaceAllLabel.title = "Replace All"
    this.replaceAll = document.createElement("input");
    this.replaceAll.type = "checkbox"
    this.replaceAll.className = "codemirror-ui-checkbox"
    replaceAllLabel.appendChild(this.replaceAll);
    replaceAllLabel.appendChild(document.createTextNode("All"));

    findBar.appendChild(this.findString);
    findBar.appendChild(this.findButton);
    findBar.appendChild(caseLabel);
    findBar.appendChild(regLabel);

    findBar.appendChild(this.replaceString);
    findBar.appendChild(this.replaceButton);
    findBar.appendChild(replaceAllLabel);
    return findBar;
  },
  initPopupFindControl: function() {
    var findBar = this.createFindBar();

    this.popupFindWrap = document.createElement("div");
    this.popupFindWrap.className = "codemirror-ui-popup-find-wrap";

    this.popupFindWrap.appendChild(findBar);

    var buttonDef = this.buttonDefs['searchClose'];
    this.addButton(buttonDef[0], buttonDef[1], buttonDef[2], buttonDef[3], this.popupFindWrap);

    this.buttonFrame.appendChild(this.popupFindWrap);

  },
  initFindControl: function() {
    var findBar = this.createFindBar();
    this.buttonFrame.appendChild(findBar);
  },
  find: function( start ) {
    if(start == null){
      start = this.mirror.getCursor();
    }
    var findString = this.findString.value;
    if (findString == null || findString == '') {
      alert('You must enter something to search for.');
      return;
    }
    if (this.regex.checked) {
      findString = new RegExp(findString);
    }

    this.cursor = this.mirror.getSearchCursor(findString, start, !this.caseSensitive.checked );
    var found = this.cursor.findNext();
    if (found) {
      this.mirror.setSelection(this.cursor.from(),this.cursor.to())
      //this.cursor.select();
    } else {
      if (confirm("No more matches.  Should we start from the top?")) {
        this.cursor = this.mirror.getSearchCursor(findString, 0, !this.caseSensitive.checked);
        found = this.cursor.findNext();
        if (found) {
          this.mirror.setSelection(this.cursor.from(),this.cursor.to())
          //this.cursor.select();
        } else {
          alert("No matches found.");
        }
      }
    }
  },
  replace: function() {
    if (this.replaceAll.checked) {
      var cursor = this.mirror.getSearchCursor(this.findString.value, this.mirror.getCursor(), !this.caseSensitive.checked);
      while (cursor.findNext())
        this.mirror.replaceRange(this.replaceString.value,cursor.from(),cursor.to())
        //cursor.replace(this.replaceString.value);
    } else {
      this.mirror.replaceRange(this.replaceString.value,this.cursor.from(),this.cursor.to())
      //this.cursor.replace(this.replaceString.value);
      this.find();
    }
  },
  initWordWrapControl: function() {
    var wrapDiv = document.createElement("div");
    wrapDiv.className = "codemirror-ui-wrap"

    var label = document.createElement("label");

    this.wordWrap = document.createElement("input");
    this.wordWrap.type = "checkbox"
    this.wordWrap.checked = true;
    label.appendChild(this.wordWrap);
    label.appendChild(document.createTextNode("Word Wrap"));
    this.wordWrap.onchange = this.toggleWordWrap.bind(this);
    wrapDiv.appendChild(label);
    this.buttonFrame.appendChild(wrapDiv);
  },
  toggleWordWrap: function() {
    if (this.wordWrap.checked) {
      this.mirror.setTextWrapping("nowrap");
    } else {
      this.mirror.setTextWrapping("");
    }
  },
  addButton: function(name, action, image, func, frame) {
    var button = document.createElement("a");
    //button.href = "#";
    button.className = "codemirror-ui-button " + action;
    button.title = name;
    button.func = func.bind(this);
    button.onclick = function(event) {
      //alert(event.target);
      event.target.func();
      return false;
      //this.self[action].call(this);
      //eval("this."+action)();
    }
    .bind(this, func);
    var img = document.createElement("img");
    img.src = image;
    img.border = 0;
    img.func = func.bind(this);
    button.appendChild(img);
    frame.appendChild(button);
    if (action == 'save') {
      this.saveButton = button;
    }
    if (action == 'undo') {
      this.undoButton = button;
    }
    if (action == 'redo') {
      this.redoButton = button;
    }
  },
  classNameRegex: function(className) {
    var regex = new RegExp("(.*) *" + className + " *(.*)");
    return regex;
  },
  addClass: function(element, className) {
    if (!element.className.match(this.classNameRegex(className))) {
       element.className += " " + className;
    }
  },
  removeClass: function(element, className) {
    var m = element.className.match(this.classNameRegex(className))
    if (m) {
      element.className = m[1] + " " + m[2];
    }
  },
  editorChanged: function() {
    if(!this.mirror) {
      return
    }
    var his = this.mirror.historySize();
    if (his['undo'] > 0) {
      this.removeClass(this.saveButton, 'inactive');
      this.removeClass(this.undoButton, 'inactive');
    } else {
      this.addClass(this.saveButton, 'inactive');
      this.addClass(this.undoButton, 'inactive');
    }
    if (his['redo'] > 0) {
      this.removeClass(this.redoButton, 'inactive');
    } else {
      this.addClass(this.redoButton, 'inactive');
    }
    //alert("undo size = " + his['undo'] + " and redo size = " + his['redo']);
  },
  save: function() {
    this.options.saveCallback();
    this.addClass(this.saveButton, 'inactive');
  },
  undo: function() {
    this.mirror.undo();
  },
  redo: function() {
    this.mirror.redo();
  },
  replaceSelection: function(newVal) {
    this.mirror.replaceSelection(newVal);
    this.searchWindow.focus();
  },
  raise_search_window: function() {
    //alert('raising window!');
    this.searchWindow.focus();
  },
  find_replace_window: function() {
    if (this.searchWindow == null) {
      this.searchWindow = window.open(this.options.path + "find_replace.html", "mywindow", "scrollbars=1,width=400,height=350,modal=yes");
      this.searchWindow.codeMirrorUI = this;
    }
    this.searchWindow.focus();
  },
  find_replace_popup: function() {
    //alert('Hello!');
    this.popupFindWrap.className = "codemirror-ui-popup-find-wrap active";
    this.findString.focus();
  },
  find_replace_popup_close: function() {
    //alert('Hello!');
    this.popupFindWrap.className = "codemirror-ui-popup-find-wrap";
  },
  /*
   find_replace: function(){
   this.find_replace = document.createElement("div");
   this.find_replace.className = "codemirror-search-replace";
   this.find_replace.innerHTML = "Just a test!";
   this.home.appendChild(this.find_replace);
   },

   search: function(){
   var text = prompt("Enter search term:", "");
   if (!text)
   return;

   var first = true;
   do {
   var cursor = this.mirror.getSearchCursor(text, first);
   first = false;
   while (cursor.findNext()) {
   cursor.select();
   if (!confirm("Search again?"))
   return;
   }
   }
   while (confirm("End of document reached. Start over?"));
   },

   replace: function(){
   // This is a replace-all, but it is possible to implement a
   // prompting replace.
   var from = prompt("Enter search string:", ""), to;
   if (from)
   to = prompt("What should it be replaced with?", "");
   if (to == null)
   return;

   var cursor = this.mirror.getSearchCursor(from, false);
   while (cursor.findNext())
   cursor.replace(to);
   },
   */
  jump: function() {
    var line = prompt("Jump to line:", "");
    if (line && !isNaN(Number(line))) {
      this.mirror.setCursor(Number(line),0);
      this.mirror.setSelection({line:Number(line),ch:0},{line:Number(line)+1,ch:0});
      this.mirror.focus();
    }
  },
  /*
   line: function(){
   alert("The cursor is currently at line " + this.mirror.currentLine());
   this.mirror.focus();
   },

   macro: function(){
   var name = prompt("Name your constructor:", "");
   if (name)
   this.mirror.replaceSelection("function " + name + "() {\n  \n}\n\n" + name + ".prototype = {\n  \n};\n");
   },
   */
  reindent: function() {
    var lineCount = this.mirror.lineCount();
    for(var line = 0; line < lineCount; line++) {
      this.mirror.indentLine(line);
    }
  },
  about : function() {
    string = "CodeMirror-UI was written by Jeremy Green (http://www.octolabs.com/) as a light interface around CodeMirror by Marijn Haverbeke (http://codemirror.net)."
    string += "\n\n"
    string += "Documentation and the code can be found at https://github.com/jagthedrummer/codemirror-ui/."
    alert(string);
  },
  reindentSelection: function() {
    var cur = this.mirror.getCursor()
    //console.log(cur)
    var start = this.mirror.getCursor(true)["line"]
    var end = this.mirror.getCursor(false)["line"]
    for(var line = start; line <= end; line++) {
      this.mirror.indentLine(line);
    }
    //this.mirror.reindentSelection();

  },
  // Event handler registration. If disconnect is true, it'll return a
  // function that unregisters the handler.
  // Borrowed from CodeMirror + modified
  connect: function (node, type, handler, disconnect) {
    /*function wrapHandler(event) {
      handler(new Event(event || window.event));
    }*/

    if (typeof node.addEventListener == "function") {
      node.addEventListener(type, handler, false);
      if (disconnect)
        return function() {
          node.removeEventListener(type, handler, false);
        };
    } else {
      node.attachEvent("on" + type, handler);
      if (disconnect)
        return function() {
          node.detachEvent("on" + type, handler);
        };
    }
  }
};

/*
 * This makes coding callbacks much more sane
 */
Function.prototype.bind = function(scope) {
  var _function = this;

  return function() {
    return _function.apply(scope, arguments);
  }
}
