namespace :dev do
  namespace :news do
    # Run this task with: rails "dev:news:data[3]"
    # replacing 3 with any number to indicate how many times you want this code to be executed.
    desc 'Create news for all the combinations of severities and communication scopes'
    task :data, [:repetitions] => :development_environment do |_t, args|
      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      # Users
      admin = User.where(login: 'Admin').first || create(:admin_user, login: 'Admin')

      repetitions.times do
        puts('Creating news for each combination of severity and communication scope')
        StatusMessage.severities.each do |severity_name, _severity_index|
          StatusMessage.communication_scopes.each do |communication_scope_name, _severity_index|
            create(:status_message, message: "#{communication_scope_name} - #{Faker::Lorem.paragraph}",
                                    severity: severity_name,
                                    communication_scope: communication_scope_name,
                                    user: admin)
          end
        end
      end
    end
  end
end
