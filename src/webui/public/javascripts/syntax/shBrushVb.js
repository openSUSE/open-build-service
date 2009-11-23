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

dp.sh.Brushes.Vb = function()
{
	var keywords =	'AddHandler AddressOf AndAlso Alias And Ansi As Assembly Auto ' +
					'Boolean ByRef Byte ByVal Call Case Catch CBool CByte CChar CDate ' +
					'CDec CDbl Char CInt Class CLng CObj Const CShort CSng CStr CType ' +
					'Date Decimal Declare Default Delegate Dim DirectCast Do Double Each ' +
					'Else ElseIf End Enum Erase Error Event Exit False Finally For Friend ' +
					'Function Get GetType GoSub GoTo Handles If Implements Imports In ' +
					'Inherits Integer Interface Is Let Lib Like Long Loop Me Mod Module ' +
					'MustInherit MustOverride MyBase MyClass Namespace New Next Not Nothing ' +
					'NotInheritable NotOverridable Object On Option Optional Or OrElse ' +
					'Overloads Overridable Overrides ParamArray Preserve Private Property ' +
					'Protected Public RaiseEvent ReadOnly ReDim REM RemoveHandler Resume ' +
					'Return Select Set Shadows Shared Short Single Static Step Stop String ' +
					'Structure Sub SyncLock Then Throw To True Try TypeOf Unicode Until ' +
					'Variant When While With WithEvents WriteOnly Xor';

	this.regexList = [
		{ regex: new RegExp('\'.*$', 'gm'),							css: 'comment' },			// one line comments
		{ regex: dp.sh.RegexLib.DoubleQuotedString,					css: 'string' },			// strings
		{ regex: new RegExp('^\\s*#.*', 'gm'),						css: 'preprocessor' },		// preprocessor tags like #region and #endregion
		{ regex: new RegExp(this.GetKeywords(keywords), 'gm'),		css: 'keyword' }			// c# keyword
		];

	this.CssClass = 'dp-vb';
};

dp.sh.Brushes.Vb.prototype	= new dp.sh.Highlighter();
dp.sh.Brushes.Vb.Aliases	= ['vb', 'vb.net'];
