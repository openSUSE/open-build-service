require 'factory_bot'

namespace :dev do
  namespace :label_templates do
    desc 'Create label templates for the home:Admin project'
    task :data, [:repetitions] => :development_environment do |_t, args|
      include FactoryBot::Syntax::Methods

      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i

      repetitions.times do
        project = Project.find_by_name('home:Admin')
        create(:label_template, project: project)
      end
    end
  end
end
