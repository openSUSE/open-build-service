# Pin npm packages by running ./bin/importmap

pin "application"
pin_all_from 'app/javascript/src', under: 'src', to: 'src'
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "https://ga.jspm.io/npm:@hotwired/stimulus@3.2.1/dist/stimulus.js"
pin "@avo-hq/marksmith", to: "@avo-hq--marksmith.js" # 0.4.7
