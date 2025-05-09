namespace :dev do
  # Run this task with: rails dev:requests:assignments
  desc 'Assigns a package and a project to some users'
  task assignments: :development_environment do
    require 'factory_bot'
    include FactoryBot::Syntax::Methods

    admin = User.default_admin
    iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
    project = RakeSupport.find_or_create_project('home:Admin', admin)
    package = Package.where(name: 'hello_world', project: project).first ||
              create(:package_with_files, name: 'hello_world', project: project)
    Assignment.create!(assigner: admin, assignee: iggy, package: package)
  end
end
