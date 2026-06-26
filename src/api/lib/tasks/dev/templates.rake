namespace :dev do
  namespace :templates do
    # Run this task with: rails dev:templates:create
    desc 'Creates a set of package templates'
    task create: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      puts 'Creating templates...'

      admin = User.default_admin
      User.session = admin
      User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')

      # Set target project and package
      template_project = Project.find_by(name: 'templates') || create(:project, name: 'templates') # openSUSE:Factory

      attrib_type = AttribType.find_by_namespace_and_name!('OBS', 'PackageTemplates')
      Attrib.find_by(attrib_type:, project: template_project) || create(:attrib, attrib_type:, project: template_project)

      Package.where(name: 'template_a', project: template_project).first ||
        create(:package_with_templates, name: 'template_a', project: template_project)

      Package.where(name: 'template_b', project: template_project).first ||
        create(:package_with_templates, name: 'template_b', project: template_project)
    end
  end
end
