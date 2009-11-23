dp.sh.Brushes.Diff = function()
{
	this.regexList = [
		{ regex: /^\+\+\+.*$/gm,		css: 'color2' },
		{ regex: /^\-\-\-.*$/gm,		css: 'color2' },
		{ regex: /^\s.*$/gm,			css: 'color1' },
		{ regex: /^@@.*@@$/gm,			css: 'variable' },
		{ regex: /^\+[^\+]{1}.*$/gm,	css: 'string' },
		{ regex: /^\-[^\-]{1}.*$/gm,	css: 'comments' }
		];
};

dp.sh.Brushes.Diff.prototype	= new dp.sh.Highlighter();
dp.sh.Brushes.Diff.Aliases	= ['diff', 'patch'];
