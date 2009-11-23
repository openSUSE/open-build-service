/**
 * Code Syntax Highlighter.
 * Version 1.5.2
 * Copyright (C) 2004-2008 Alex Gorbatchev
 * http://www.dreamprojections.com/syntaxhighlighter/
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, version 3 of the License.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/** Contributed by Yegor Jbanov and David Bernard. */
dp.sh.Brushes.Scala = function()
{
	var keywords =	'val sealed case def true trait implicit forSome import match object null finally super ' +
	                'override try lazy for var catch throw type extends class while with new final yield abstract ' +
	                'else do if return protected private this package false';

	var keyops =	'[_:=><%#@]+';

	this.regexList = [
		{ regex: dp.sh.RegexLib.SingleLineCComments,							css: 'comment' },		// one line comments
		{ regex: dp.sh.RegexLib.MultiLineCComments,								css: 'comment' },		// multiline comments
		{ regex: new RegExp("(['\"]{3})([^\\1])*?\\1", 'gm'),                   css: 'string'  },		// multi-line strings
		{ regex: new RegExp('"(?!")(?:\\.|\\\\\\"|[^\\""\\n\\r])*"', 'gm'),     css: 'string'  },       // double-quoted string
		{ regex: dp.sh.RegexLib.SingleQuotedString,								css: 'string'  },		// strings
		{ regex: new RegExp('\\b([\\d]+(\\.[\\d]+)?|0x[a-f0-9]+)\\b', 'gi'),	css: 'number'  },		// numbers
		{ regex: new RegExp(this.GetKeywords(keywords), 'gm'),					css: 'keyword' },		// keywords
		{ regex: new RegExp(keyops, 'gm'),										css: 'keyword' }		                    // scala keyword
		];

	this.CssClass = 'dp-j';
	this.Style =	'.dp-j .annotation { color: #646464; }' +
					'.dp-j .number { color: #C00000; }';
}

dp.sh.Brushes.Scala.prototype	= new dp.sh.Highlighter();
dp.sh.Brushes.Scala.Aliases		= ['scala'];
