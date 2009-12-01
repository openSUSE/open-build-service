dp.sh.Brushes.Prjconf = function()
{
	var keywords =	'Conflict Ignore Keep Macros Optflags Order Prefer ExportFilter Type Patterntype ' +
                        'Preinstall Repotype Required Runscripts Substitute Support VMinstall'

	this.regexList = [
		{ regex: new RegExp('#(.*)$', 'gm'),	    css: 'comment' },	// one line and multiline comments
		{ regex: new RegExp('%(.*)$', 'gm'),       css: 'rpm' },
		{ regex: dp.sh.RegexLib.DoubleQuotedString, css: 'string' },	// double quoted strings
                { regex: dp.sh.RegexLib.SingleQuotedString, css: 'string' },	// single quoted strings
		{ regex: new RegExp(this.GetKeywords(keywords), 'gmi'),	css: 'keyword' } // keyword
		];

	this.CssClass = 'dp-prjconf';
	this.Style =	'.dp-prjconf .func { color: #ff1493; } ' +
			'.dp-prjconf .rpm { color: orange }';
}

dp.sh.Brushes.Prjconf.prototype	= new dp.sh.Highlighter();
dp.sh.Brushes.Prjconf.Aliases	= ['prjconf'];
