var SpecParser = Editor.Parser = (function() {

	function wordRegexp(words) {
		return new RegExp("^(?:" + words.join("|") + ")$", "i");
	}
	
	var section_keywords = wordRegexp([
		"%description","%build","%install","%clean","%files","%changelog","%prep","%post","%pre","%postun","%preun"
	]);

	var tags = wordRegexp([
		"Patch\\d+","Source\\d+","Name","Summary","Version","Release","License","Group","BuildRoot","AutoReqProv","Url","BuildRequires","Requires","PreReq"
	]);

	var urls = wordRegexp([
		"http","https","ftp"
	]);
	
	var known_macros = wordRegexp([
		"%defattr","%make_jobs","%cmake_kde4","%prep","%setup","%dir"
	]);

	var tokenizeSpec = (function() {

		function normal(source, setState) {
			var ch = source.next();
			var word,type;
			
			//check comments
			if ( ch == '#' ) {
				while (!source.endOfLine()) source.next();
					return "spec-comment";
			}
			//check env variables e.g. $RPM_BUILD_ROOT
			else if ( ch == '$' ) {
				source.nextWhileMatches(/[_\w]/);
				return "spec-env-variable";
			}
			//mark path
			else if ( ch == '/' ) {
				source.nextWhileMatches(/[._-\w]/);
				word = source.get();
				if (word != '')
					 return {style: "spec-path", content: word};
			}
			//mark extentsion in path ( .png .tar.bz .html )
			else if ( ch == '.' ) {
				source.nextWhileMatches(/[a-zA-Z]/);
				word = source.get();
				if (word != '')
					 return {style: "spec-path", content: word};
			}

			//grab word from stream and process it then (char '%' included)
			source.nextWhileMatches(/[\w]/);
			word = source.get();

			//check urls
			if (urls.test(word))
			{
				source.nextWhileMatches(/[._/:\w]/);
				word += source.get();
				type = "spec-url";
			}

			//check tags
			if (tags.test(word))
			{
				//after tag is colon and between tag and colon could be whitespace
				source.nextWhileMatches(/[\s]/);
				var colon = source.get();
				word += colon;
				source.nextWhileMatches(/[:]/);
				var colon = source.get();
				word += colon;
				//check if is colon after tag, if yes mark all chars as tag
				if (/\s*:/.test(colon))
				{
					type = "spec-tag";
				}
			}

			//these keywords begin with % and marks basic parts (sections) of spec file
			if (section_keywords.test(word))
				type = "spec-keyword";
			else if (known_macros.test(word))
				type = "spec-macro";
			else if (word[0] == '%' && word.length>1)
			{
				//macro contains not only % character
				type = "spec-macro";
			}
			else if (word[0] == '%' && word.length==1)
			{
				//if we have only % character check if next keyword is macro e.g.: {name}
				if ( source.peek() == '{' )
				{
					source.next();
					word += source.get();
					//we have character '{' so, now read the alphanumeric characters and underscore
					source.nextWhileMatches(/[\w]/);
					word += source.get();
					//and check if we finished with '}'
					if (source.peek() == '}')
					{
						//if yes we got macro with brackets
						source.next();
						word = word + source.get();;
						type = "spec-macro-brackets";
					}
				}
			}

			return {style: type, content: word};
		}

		return function(source, startState) {
			return tokenizer(source, startState || normal);
		};
	})();

	function parseSpec(source) {
		var tokens = tokenizeSpec(source);
		var context = null, indent = 0, col = 0;
	
		function pushContext(type, width, align) {
		  context = {prev: context, indent: indent, col: col, type: type, width: width, align: align};
		}

		function popContext() {
		  context = context.prev;
		}

		var iter = {
			next: function() {
				var token = tokens.next();
				var type = token.style, content = token.content, width = token.value.length;
				return token;
			},

			copy: function() {
				var _context = context, _indent = indent, _col = col, _tokenState = tokens.state;
				return function(source) {
					tokens = tokenizeSpec(source, _tokenState);
					context = _context;
					indent = _indent;
					col = _col;
					return iter;
				};
			}
		};
		return iter;
	}

	return {make: parseSpec, electricChars: ")"};

})();
