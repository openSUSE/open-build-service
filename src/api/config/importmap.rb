# Pin npm packages by running ./bin/importmap

pin "application"
pin_all_from 'app/javascript/src', under: 'src', to: 'src'
pin "@hotwired/turbo-rails", to: "turbo.min.js"
