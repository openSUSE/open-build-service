/**
 * Copyright (c) 2011, SUSE Linux Products GmbH.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program (see the file COPYING); if not, write to the
 * Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
 */

;(function()
{
    // CommonJS
    typeof(require) != 'undefined' ? SyntaxHighlighter = require('shCore').SyntaxHighlighter : null;

    function Brush()
    {
        var functions = 'abs avg case cast coalesce convert count current_timestamp ' +
                        'current_user day isnull left lower month nullif replace right ' +
                        'session_user space substring sum system_user upper user year';
        var operators = '^debug_package ^description ^prep ^setup ^build ^install ^files ^clean ^changelog';

        this.regexList = [
            { regex: /^\s*#(.*)$/gm, css: 'comments' },
            { regex: SyntaxHighlighter.regexLib.doubleQuotedString, css: 'string' }, // strings
            { regex: SyntaxHighlighter.regexLib.singleQuotedString, css: 'string' }, // strings
            { regex: /%(\{?\??[\w-]*\}?)/gm, css: 'rpm' },
            { regex: /\$\w*/gm, css: 'variable'},
            { regex: /\${\w*}/gm, css: 'variable'},
            { regex: new RegExp(this.getKeywords(functions), 'gm'), css: 'functions bold' },
            { regex: /^\w+(\((pre|post)\))?:/gm, css: 'keyword bold'},
            { regex: new RegExp(this.getKeywords(operators), 'gmi'), css: 'operator bold' }
        ];
    };

    Brush.prototype = new SyntaxHighlighter.Highlighter();
    Brush.aliases = ['spec'];

    SyntaxHighlighter.brushes.Spec = Brush;

    // CommonJS
    typeof(exports) != 'undefined' ? exports.Brush = Brush : null;
})();
