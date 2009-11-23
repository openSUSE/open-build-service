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

dp.sh.Brushes.Java = function()
{
	var keywords =	'abstract assert boolean break byte case catch char class const ' +
			'continue default do double else enum extends ' +
			'false final finally float for goto if implements import ' +
			'instanceof int interface long native new null ' +
			'package private protected public return ' +
			'short static strictfp super switch synchronized this throw throws true ' +
			'transient try void volatile while';

	this.regexList = [
		{ regex: dp.sh.RegexLib.SingleLineCComments,							css: 'comment' },		// one line comments
		{ regex: dp.sh.RegexLib.MultiLineCComments,								css: 'comment' },		// multiline comments
		{ regex: dp.sh.RegexLib.DoubleQuotedString,								css: 'string' },		// strings
		{ regex: dp.sh.RegexLib.SingleQuotedString,								css: 'string' },		// strings
		{ regex: new RegExp('\\b([\\d]+(\\.[\\d]+)?|0x[a-f0-9]+)\\b', 'gi'),	css: 'number' },		// numbers
		{ regex: new RegExp('(?!\\@interface\\b)\\@[\\$\\w]+\\b', 'g'),			css: 'annotation' },	// annotation @anno
		{ regex: new RegExp('\\@interface\\b', 'g'),							css: 'keyword' },		// @interface keyword
		{ regex: new RegExp(this.GetKeywords(keywords), 'gm'),					css: 'keyword' }		// java keyword
		];

	this.CssClass = 'dp-j';
	this.Style =	'.dp-j .annotation { color: #646464; }' +
					'.dp-j .number { color: #C00000; }';
};

dp.sh.Brushes.Java.prototype	= new dp.sh.Highlighter();
dp.sh.Brushes.Java.Aliases	= ['java'];
