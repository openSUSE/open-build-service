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
        var archs = 'i386 i586 i686 x86_64 ppc ppc64 ia64 s390 s390x sparc sparc64 sparcv9';

        this.regexList = [
            { regex: /^\s*#(.*)$/gm, css: 'comments' },
            { regex: /\$\(.*\)/gm, css: 'script' },
            { regex: /\${\w*}/gm, css: 'variable' },
            { regex: /\$\w+/gm, css: 'variable' },
            { regex: /^\w+(\(\w+\))?:/gm, css: 'keyword bold' }, // rpm preamble keywords
            { regex: /%(ifnarch|ifarch|if|else|endif)/gm, css: 'script' }, // rpm control flow macros
            { regex: /%(\{?\??[\w-]+\}?)/gm, css: 'rpm' },
            { regex: new RegExp(this.getKeywords(archs), 'gm'), css: 'architecture' },
            { regex: /\s+\d+\s+/gm, css: 'value' }
        ];
    };

    Brush.prototype = new SyntaxHighlighter.Highlighter();
    Brush.aliases = ['prjconf'];

    SyntaxHighlighter.brushes.Prjconf = Brush;

    // CommonJS
    typeof(exports) != 'undefined' ? exports.Brush = Brush : null;
})();
