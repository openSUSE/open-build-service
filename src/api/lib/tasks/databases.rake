namespace :db do
  desc 'Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)'
  task migrate: :environment do
    puts ''
    puts 'warning: db:migrate only migrates your database structure, not the data contained in it.'
    puts 'warning for migrating your data run data:migrate'
    puts ''
  end

  namespace :backfill do
    desc 'Backfill the tokens executor_id column with the user_id'
    task token_executor: :environment do
      Token.unscoped.in_batches do |relation|
        relation.each do |token|
          token.update(executor_id: token.user.id)
        end
        sleep(0.01) # throttle
      end
    end
  end
end
