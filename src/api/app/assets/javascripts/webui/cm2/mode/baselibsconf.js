// Quick and dirty baselibs.conf file highlighting
//
// reuses "spec" and "diff" mode styles

CodeMirror.defineMode("baselibsconf", function(config, modeConfig) {
  var directive = /^\s+(arch|targettype|targetarch|prefix|legacyversion|extension|configdir|targetname|requires|prereq|provides|conflicts|recommends|suggests|supplements|obsoletes|autoreqprov|pre\(in\)|preun|pre|post\(in\)|postun|post|baselib|config)/;
  var file_inclusion = /^\s+\+.*/;
  var control_flow_complex = /^%(ifnarch|ifarch|if)/; // rpm control flow macros
  var control_flow_simple = /^%(else|endif)/; // rpm control flow macros
  var operators = /^(\!|\?|\<\=|\<|\>\=|\>|\=\=|\&\&|\|\|)/; // operators in control flow macros
  var macro = /^\<(extension|name|version|targettype|prefix)\>/;

  return {
    startState: function () {
        return {
          controlFlow: false,
          macroParameters: false,
          directive: false
        };
    },
    token: function (stream, state) {
      var ch = stream.peek();
      if (stream.sol()) {
        if (ch == "#") { stream.skipToEnd(); return "comment"; }
        if (stream.match(/^\w+[\w\-\._]+/)) {
          state.directive = false;
          return "preamble";
        }
        if (stream.match(file_inclusion)) { return "plus"; }
        if (stream.match(directive)) {
          // TODO: Custom handling for various directives, e.g. red color for "requires -gtk2-<targettype>"
          state.directive = true;
          return "section";
        }
      }

      if (stream.match(macro)) { return "macro"; } // Stuff like '<targettype>'

      if (stream.match(/^\$\w+/)) { return "def"; } // Variables like '$RPM_BUILD_ROOT'
      if (stream.match(/^\$\{\w+\}/)) { return "def"; } // Variables like '${RPM_BUILD_ROOT}'

      if (state.controlFlow) {
        if (stream.match(operators)) { return "operator"; }
        if (stream.match(/^(\d+)/)) { return "number"; }
        if (stream.eol()) { state.controlFlow = false; }
      }

      // Macros like '%make_install' or '%attr(0775,root,root)'
      if (stream.match(/^%[\w]+/)) {
        if (stream.match(/^\(/)) { state.macroParameters = true; }
        return "macro";
      }
      if (state.macroParameters) {
        if (stream.match(/^\d+/)) { return "number";}
        if (stream.match(/^\)/)) {
          state.macroParameters = false;
          return "macro";
        }
      }
      if (stream.match(/^%\{\??[\w \-]+\}/)) { return "macro"; } // Macros like '%{defined fedora}'

      //TODO: Include bash script sub-parser (CodeMirror supports that)
      stream.next();
      return null;
    }
  };
});

CodeMirror.defineMIME("text/vnd.openbuildservice.baselibsconf", "baselibsconf");

