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

/** Created by Andres Almiray (http://jroller.com/aalmiray/entry/nice_source_code_syntax_highlighter). */
dp.sh.Brushes.Groovy = function()
{
	var keywords =	'as assert break case catch class continue def default do else extends finally ' +
					'if in implements import instanceof interface new package property return switch ' +
					'throw throws try while';
	var types    =  'void boolean byte char short int long float double';
	var modifiers = 'public protected private static';
	var constants = 'null';
	var methods   = 'allProperties count get size '+
					'collect each eachProperty eachPropertyName eachWithIndex find findAll ' +
					'findIndexOf grep inject max min reverseEach sort ' +
					'asImmutable asSynchronized flatten intersect join pop reverse subMap toList ' +
					'padRight padLeft contains eachMatch toCharacter toLong toUrl tokenize ' +
					'eachFile eachFileRecurse eachB yte eachLine readBytes readLine getText ' +
					'splitEachLine withReader append encodeBase64 decodeBase64 filterLine ' +
					'transformChar transformLine withOutputStream withPrintWriter withStream ' +
					'withStreams withWriter withWriterAppend write writeLine '+
					'dump inspect invokeMethod print println step times upto use waitForOrKill '+
					'getText';

	this.regexList = [
		{ regex: dp.sh.RegexLib.SingleLineCComments,							css: 'comment' },	// one line comments
		{ regex: dp.sh.RegexLib.MultiLineCComments,								css: 'comment' },	// multiline comments
		{ regex: dp.sh.RegexLib.DoubleQuotedString,								css: 'string' },	// strings
		{ regex: dp.sh.RegexLib.SingleQuotedString,								css: 'string' },	// strings
		{ regex: new RegExp('""".*"""','g'),									css: 'string' },	// GStrings
		{ regex: new RegExp('\\b([\\d]+(\\.[\\d]+)?|0x[a-f0-9]+)\\b', 'gi'),	css: 'number' },	// numbers
		{ regex: new RegExp(this.GetKeywords(keywords), 'gm'),					css: 'keyword' },	// goovy keyword
		{ regex: new RegExp(this.GetKeywords(types), 'gm'),						css: 'type' },		// goovy/java type
		{ regex: new RegExp(this.GetKeywords(modifiers), 'gm'),					css: 'modifier' },	// java modifier
		{ regex: new RegExp(this.GetKeywords(constants), 'gm'),					css: 'constant' },	// constants
		{ regex: new RegExp(this.GetKeywords(methods), 'gm'),					css: 'method' }		// methods
		];

	this.CssClass	= 'dp-g';
	this.Style		= '.dp-g .comment { color: rgb(63,127,95); }' +
					'.dp-g .string { color: rgb(42,0,255); }' +
					'.dp-g .keyword { color: rgb(127,0,85); font-weight: bold }' +
					'.dp-g .type { color: rgb(0,127,0); font-weight: bold }' +
					'.dp-g .modifier { color: rgb(100,0,100); font-weight: bold }' +
					'.dp-g .constant { color: rgb(255,0,0); font-weight: bold }' +
					'.dp-g .method { color: rgb(255,96,0); font-weight: bold }' +
					'.dp-g .number { color: #C00000; }'
					;
}

dp.sh.Brushes.Groovy.prototype	= new dp.sh.Highlighter();
dp.sh.Brushes.Groovy.Aliases	= ['groovy'];
