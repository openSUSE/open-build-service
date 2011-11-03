// Quick and dirty spec file highlighting

CodeMirror.defineMode("spec", function(config, modeConfig) {
  var arch = /^(i386|i586|i686|x86_64|ppc64|ppc|ia64|s390x|s390|sparc64|sparcv9|sparc|noarch|alphaev6|alpha|hppa|mipsel)/;

  var preamble = /^(Name|Version|Release|License|Summary|Url|Group|Source|BuildArch|BuildRequires|BuildRoot|AutoReqProv|Provides|Requires(\(\w+\))?|Obsoletes|Conflicts|Recommends|Source\d*|Patch\d*|ExclusiveArch|NoSource|Supplements):/;
  var section = /^%(debug_package|package|description|prep|build|install|files|clean|changelog|preun|postun|pre|post|triggerin|triggerun|pretrans|posttrans|verifyscript|check|triggerpostun|triggerprein|trigger)/;

  var control_flow_macros = /^%(ifnarch|ifarch|if|else|endif|\|\||\&\&)/; // rpm control flow macros

  return {
    token: function(stream) {
      var ch = stream.peek();
      if (ch == "#") { stream.skipToEnd(); return "comment"; }

      //if (stream.match(/^\s+\d+\s+/)) { return "number"; }
      //TODO: Doesn't work with current comment matching:
      //if (stream.match(/^[A-Za-z]\#\d#+/)) { return "issue"; } // Issue tracker abbreviations like 'bnc#1234'

      if (stream.sol()) {
        if (stream.match(preamble)) { return "preamble"; }
        if (stream.match(section)) { return "section"; }
      }

      if (stream.match(/^\$\w+/)) { return "def"; } // Variables like '$RPM_BUILD_ROOT'
      if (stream.match(/^\$\{\w+\}/)) { return "def"; } // Variables like '${RPM_BUILD_ROOT}'

      //TODO: Support expressions in control flow macros like '%if ! %foo || %bar && %spam':
      if (stream.match(control_flow_macros)) { return "builtin"; }
      //TODO: Match architectures only behind '%ifarch' ?!?
      if (stream.match(arch)) { return "number"; }
      //TODO: Include stuff like %attr(0775,root,root), not possible with stateless parser
      if (stream.match(/^%[\w]+/)) { return "macro"; } // Macros like '%make_install'
      if (stream.match(/^%\{\??[\w \-]+\}/)) { return "macro"; } // Macros like '%{defined fedora}'

      //TODO: Include bash script sub-parser (CodeMirror supports that)
      //var shell_cmds = /^(export|mkdir|cd|cp|rm|mv|chmod|chown|install|make)\s+(-\w+)*/;
      //if (stream.match(/^\$\(.*\)/)) { return "script"; }
      //if (stream.match(shell_cmds)) { return "script"; }

      stream.next();
      return null;
    }
  };
});

CodeMirror.defineMIME("text/x-spec", "spec");


