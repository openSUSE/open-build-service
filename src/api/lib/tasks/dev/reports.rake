#!/usr/bin/env ruby

namespace :dev do
  namespace :reports do
    desc 'Create reports for several contents like Comments, Packages, Projects and Users'
    task data: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      factory = Project.where(name: 'openSUSE:Factory').first
      admin = User.get_default_admin
      iggy = User.find_by(login: 'Iggy')
      [
        factory.comments.create!(user: admin, body: 'This project is crap!'),
        create(:package_with_files, name: 'crappy_package', project: factory),
        create(:project, name: 'some_crappy_project_name', commit_user: admin),
        create(:confirmed_user, login: 'crapboy')
      ].each do |reportable|
        Report.create!(reportable: reportable, user: iggy, reason: 'Watch your language, please')
      end
    end
  end
end
