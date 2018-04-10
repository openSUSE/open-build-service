# frozen_string_literal: true

['.ruby-version', '.rbenv-vars', 'tmp/restart.txt', 'tmp/caching-dev.txt'].each { |path| Spring.watch(path) }
