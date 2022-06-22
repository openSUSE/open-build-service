namespace :db do
  desc 'Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)'
  task migrate: :environment do
    puts ''
    puts 'warning: db:migrate only migrates your database structure, not the data contained in it.'
    puts 'warning for migrating your data run data:migrate'
    puts ''
  end
end
