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

dp.sh.Brushes.CSharp = function()
{
	var keywords =	'abstract as base bool break byte case catch char checked class const ' +
					'continue decimal default delegate do double else enum event explicit ' +
					'extern false finally fixed float for foreach get goto if implicit in int ' +
					'interface internal is lock long namespace new null object operator out ' +
					'override params private protected public readonly ref return sbyte sealed set ' +
					'short sizeof stackalloc static string struct switch this throw true try ' +
					'typeof uint ulong unchecked unsafe ushort using virtual void while';

	this.regexList = [
		// There's a slight problem with matching single line comments and figuring out
		// a difference between // and ///. Using lookahead and lookbehind solves the
		// problem, unfortunately JavaScript doesn't support lookbehind. So I'm at a 
		// loss how to translate that regular expression to JavaScript compatible one.
//		{ regex: new RegExp('(?<!/)//(?!/).*$|(?<!/)////(?!/).*$|/\\*[^\\*]*(.)*?\\*/', 'gm'),	css: 'comment' },			// one line comments starting with anything BUT '///' and multiline comments
//		{ regex: new RegExp('(?<!/)///(?!/).*$', 'gm'),											css: 'comments' },		// XML comments starting with ///

		{ regex: dp.sh.RegexLib.SingleLineCComments,				css: 'comment' },			// one line comments
		{ regex: dp.sh.RegexLib.MultiLineCComments,					css: 'comment' },			// multiline comments
		{ regex: dp.sh.RegexLib.DoubleQuotedString,					css: 'string' },			// strings
		{ regex: dp.sh.RegexLib.SingleQuotedString,					css: 'string' },			// strings
		{ regex: new RegExp('^\\s*#.*', 'gm'),						css: 'preprocessor' },		// preprocessor tags like #region and #endregion
		{ regex: new RegExp(this.GetKeywords(keywords), 'gm'),		css: 'keyword' }			// c# keyword
		];

	this.CssClass = 'dp-c';
	this.Style = '.dp-c .vars { color: #d00; }';
};

dp.sh.Brushes.CSharp.prototype	= new dp.sh.Highlighter();
dp.sh.Brushes.CSharp.Aliases	= ['c#', 'c-sharp', 'csharp'];
