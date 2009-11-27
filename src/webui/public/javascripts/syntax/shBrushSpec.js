dp.sh.Brushes.Spec = function()
    {
        var funcs = 'abs avg case cast coalesce convert count current_timestamp ' +
        'current_user day isnull left lower month nullif replace right ' +
        'session_user space substring sum system_user upper user year';

        var keywords =	'^name ^summary ^version ^release ^source\\d* ^patch\\d* ^requires ^license ' +
        '^group ^url ^buildroot ^prefix ^buildrequires ^packager ^provides ^vendor ^autoreqprov';

        var operators =	'debug_package description prep setup build install files clean changelog';

        this.regexList = [
        {
            regex: new RegExp('#(.*)$', 'gm'),
            css: 'comment'
        },	// one line and multiline comments

        {
            regex: dp.sh.RegexLib.DoubleQuotedString,
            css: 'string'
        },	// double quoted strings

        {
            regex: dp.sh.RegexLib.SingleQuotedString,
            css: 'string'
        },	// single quoted strings

        {
            regex: new RegExp(this.GetKeywords(funcs), 'gmi'),
            css: 'func'
        },	// functions

        {
            regex: new RegExp(this.GetKeywords(operators), 'gmi'),
            css: 'op'
        },	// operators and such

        {
            regex: new RegExp(this.GetKeywords(keywords), 'gmi'),
            css: 'keyword'
        }// keyword
        ];

        this.CssClass = 'dp-spec';
        this.Style =	'.dp-spec .func { color: #ff1493; }' +
    '.dp-spec .op { color: #808080; }';
    }

dp.sh.Brushes.Spec.prototype	= new dp.sh.Highlighter();
dp.sh.Brushes.Spec.Aliases	= ['spec'];
