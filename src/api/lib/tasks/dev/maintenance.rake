namespace :dev do
  namespace :maintenance do
    # Run this task with: rails dev:maintenance:all
    desc 'Set a maintenance environment'
    task all: :development_environment do
      Rake::Task['dev:maintenance:project'].invoke
      Rake::Task['dev:maintenance:request_with_incident_actions'].invoke
      Rake::Task['dev:maintenance:request_with_release_actions'].invoke
    end

    desc 'Create a maintenance project'
    task project: 'dev:test_data:create_leap_project' do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods
      leap = Project.find_by(name: 'openSUSE:Leap:15.0')
      admin = User.get_default_admin

      admin.run_as do
        update_project = Project.find_by(name: 'openSUSE:Leap:15.0:Update') || create(:update_project, target_project: leap, name: "#{leap.name}:Update")
        unless Project.find_by(name: 'MaintenanceProject')
          create(
            :maintenance_project,
            name: 'MaintenanceProject',
            title: 'official maintenance space',
            target_project: update_project,
            maintainer: admin
          )
        end
      end
    end

    desc 'Create a request with maintenance incident actions'
    task request_with_incident_actions: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      admin = User.get_default_admin
      home_admin_project = Project.find_by(name: admin.home_project_name) # RakeSupport.find_or_create_project(admin.home_project_name, admin)

      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      request = build(
        :bs_request_with_maintenance_incident_action,
        creator: iggy
      )

      maintenance_project = Project.find_by(kind: 'maintenance')
      release_project = Project.find_by(kind: 'maintenance_release')

      # This is the first maintenance incident action, we reuse the action created by the factory
      home_iggy_project = RakeSupport.find_or_create_project(iggy.home_project_name, iggy)
      maintenance_package = create(:package, name: "maintenance_package_#{Faker::Lorem.word}", project: home_iggy_project, commit_user: iggy)

      User.session = iggy
      request.bs_request_actions.first.tap do |action|
        action.source_project = home_iggy_project
        action.source_package = maintenance_package
        action.target_project = maintenance_project
        action.target_releaseproject = release_project
        action.save!
      end

      # This is the second maintenance incident action
      another_maintenance_package = create(:package, name: "another_maintenance_package_#{Faker::Lorem.word}", project: home_iggy_project, commit_user: iggy)
      request.bs_request_actions << create(:bs_request_action,
                                           type: :maintenance_incident,
                                           source_project: home_iggy_project,
                                           source_package: another_maintenance_package,
                                           target_project: maintenance_project,
                                           target_releaseproject: release_project)

      # create(:bs_request_action_delete,
      #        target_project: home_admin_project,
      #        bs_request: request)

      puts "* Request with maintenance incident actions #{request.number} has been created."
    end


    desc 'Create a request with maintenance release actions'
    task request_with_release_actions: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      Rake::Task['dev:maintenance:project'].invoke # Really needed?
      Rake::Task['dev:maintenance:request_with_incident_actions'].invoke

      incident_action = BsRequestActionMaintenanceIncident.last
      bs_request_maintenance_incident = incident_action.bs_request

      # TODO: replace admin by a maintenance user with the right permissions
      admin = User.get_default_admin
      User.session = admin
      # We accept the incident request so the incident project is automatically created (Maintenance:ID)
      bs_request_maintenance_incident.change_state(newstate: 'accepted', force: true, user: admin.login, comment: 'We want to release already')
      incident_project = Project.last
      incident_package = incident_project.packages.last

      release_request = build(
        :bs_request_with_maintenance_release_action,
        creator: admin
      )

      release_request.bs_request_actions.first.tap do |action|
        action.source_project = incident_project.name
        action.source_package = incident_package.name
        action.target_project = incident_action.target_releaseproject
        action.target_releaseproject = nil
        action.target_package = incident_package.name
        action.save!
      end

      puts "* Request with maintenance release actions #{release_request.number} has been created."
    end
  end
end


=begin

1 target pro + 1 target pack
1 target pro + M target pack
M target pro + M target pack


 type: "maintenance_release",
 target_project: "openSUSE:Backports:SLE-15-SP4:Update",
 target_package: "patchinfo.17900",
 target_releaseproject: nil,
 source_project: "openSUSE:Maintenance:17900",
 source_package: "patchinfo",

=end
