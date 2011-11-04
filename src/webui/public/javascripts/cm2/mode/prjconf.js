// Quick and dirty prjconf file highlighting

CodeMirror.defineMode("prjconf", function(config, modeConfig) {
  var arch = /^(i386|i586|i686|x86_64|ppc64|ppc|ia64|s390x|s390|sparc64|sparcv9|sparc|noarch|alphaev6|alpha|hppa|mipsel)/;
  var prjconf = /^(Conflict|Ignore|Keep|Macros|Optflags|Order|Prefer|ExportFilter|Type|Patterntype|Preinstall|Repotype|Required|Runscripts|Substitute|Support|VMinstall):/;
  var control_flow_macros = /^%(ifnarch|ifarch|if|else|endif|\|\||\&\&)/; // rpm control flow macros

  return {
    startState: function () {
        return {
          exportFilter: false,
          controlFlow: false,
        };
    },
    token: function (stream, state) {
      var ch = stream.peek();
      if (ch == "#") { stream.skipToEnd(); return "comment"; }

      if (state.exportFilter) {
        state.exportFilter = false;
        if (stream.match(/^.*\$/)) { 
          return "string";
        }
      }

      if (stream.sol()) {
        var match;
        if (match = stream.match(prjconf)) {
          if (match[0] == "ExportFilter:") {
            state.exportFilter = true;
          }
          return "builtin";
        }
      }

      if (stream.match(/^\$\w+/)) { return "def"; } // Variables like '$RPM_BUILD_ROOT'
      if (stream.match(/^\$\{\w+\}/)) { return "def"; } // Variables like '${RPM_BUILD_ROOT}'

      //TODO: Support expressions in control flow macros like '%if ! %foo || %bar && %spam':
      if (stream.match(control_flow_macros)) { 
        state.controlFlow = true;
        return "keyword"; 
      }
      //TODO: Match architectures only behind '%ifarch' ?!?
      if (stream.match(arch)) { return "number"; }
      //TODO: Include stuff like %attr(0775,root,root), not possible with stateless parser
      if (stream.match(/^%[\w]+/)) { return "macro"; } // Macros like '%make_install'
      if (stream.match(/^%\{\??[\w \-]+\}/)) { return "macro"; } // Macros like '%{defined fedora}'

      if (state.controlFlow) {
        if (stream.match(/^(\!|\?|\=\=|\&\&|\|\|)/)) {
          return "keyword"; // Even though 'operator' would be more correct, 'keyword' looks nicer ;-)
        }
        //TODO: Match '\"foo\"' strings, but don't forget that there may be macros inside,
        if (stream.eol()) {
          state.controlFlow = false;
        }
      }

      //TODO: Include bash script sub-parser (CodeMirror supports that)

      stream.next();
      return null;
    }
  };
});

CodeMirror.defineMIME("text/x-prjconf", "prjconf");

