# Running `dev:test_data:maintenance` as part of the `rails dev:test_data`
# will create all the elements related to maintenance:

# - Maintained project (GA Project): openSUSE:Leap:15.4 and openSUSE:Backports:SLE-15-SP3
#   - Packages in the maintained project: cacti, cacti-spine and bash
# - Update Project:  openSUSE:Leap:15.4:Update and openSUSE:Backports:SLE-15-SP3:Update
# - User's branch of the Update Projects with cacti: home:Iggy:branches:OBS_Maintained:cacti
#   - Packages in the branched update project:
#     - cacti.openSUSE_Leap_15.4_Update and cacti.openSUSE_Backports_SLE-15-SP3_Update
#     - cacti-spine.openSUSE_Leap_15.4_Update and cacti-spine.openSUSE_Backports_SLE-15-SP3_Update
#     - patchinfo
# - Maintenance Project: openSUSE:Maintenance
# - Incident Project: openSUSE:Maintenance:0
# - Three Maintenance Incident Requests.

# rubocop:disable Metrics/ModuleLength
module TestData
  module Maintenance
    def create_maintained_project(project_name)
      admin = User.default_admin
      maintained_project = create(:project, name: project_name)
      create(:repository, project: maintained_project, name: 'openSUSE_Tumbleweed', architectures: ['x86_64'])
      create(:package_with_file, name: 'cacti', project: maintained_project, file_name: 'README.txt', file_content: 'Original content', commit_user: admin)
      create(:package_with_file, name: 'cacti-spine', project: maintained_project, file_name: 'README.txt', file_content: 'Original content', commit_user: admin)
      create(:package_with_file, name: 'bash', project: maintained_project, file_name: 'README.txt', file_content: 'Original content', commit_user: admin)
      maintained_project
    end

    def create_maintenance_project
      admin = User.default_admin

      create(
        :maintenance_project,
        name: 'openSUSE:Maintenance',
        title: 'official openSUSE maintenance space',
        maintainer: admin,
        commit_user: admin
      )
    end

    def create_update_project(maintained_project:, maintenance_project:)
      admin = User.default_admin

      # Update Project is a link to the Maintained Project
      create(:update_project,
             maintained_project: maintained_project,
             maintenance_project: maintenance_project,
             name: "#{maintained_project.name}:Update",
             commit_user: admin)
    end

    def mimic_mbranch(package_name)
      iggy = User.find_by(login: 'Iggy')

      # Simulate `osc mbranch cacti`., which collects all copies of the package from all projects flagged for maintenance
      # and creates branches of those packages in one single project.

      # TODO: try to convert this to a factory
      update_project_branch_hash = iggy.run_as do
        create(:branch_package,
               attribute: 'OBS:Maintained',
               package: package_name,
               update_project_attribute: 'OBS:UpdateProject')
      end

      # So far the project named `home:Iggy:branches:OBS_Maintained:cacti` is created with two `cacti.<update_project>` packages in it.

      # The result looks like this: => {:data=>{:targetproject=>"home:Iggy:branches:OBS_Maintained:cacti"}}
      update_project_branch_name = update_project_branch_hash[:data][:targetproject]
      Project.find_by(name: update_project_branch_name)
    end

    # Modify content of `<package_name>.<update project>` README.txt file and <package_name>.changes
    def add_changes_to_update_project_branch(update_project_branch)
      changes_file_content = Pathname.new(File.join('spec', 'fixtures', 'files', 'factory_package.changes')).read

      update_project_branch.packages.each do |package|
        Backend::Connection.put("/source/#{CGI.escape(update_project_branch.name)}/#{CGI.escape(package.name)}/README.txt", 'New content')
        Backend::Connection.put("/source/#{CGI.escape(update_project_branch.name)}/#{CGI.escape(package.name)}/#{CGI.escape(package.name)}.changes", changes_file_content)
      end
    end

    # We mimic `branch -M`
    def mimic_branch_maintenance(project_name:, package_name:, target_project_name:)
      iggy = User.find_by(login: 'Iggy')

      iggy.run_as do
        create(:branch_package,
               maintenance: 1,
               project: project_name,
               package: package_name,
               target_project: target_project_name)
      end
    end

    def mimic_patchinfo(project, comment = 'test comment')
      create(:patchinfo, project_name: project, package_name: 'patchinfo', comment: comment)
    end

    def create_request_with_maintenance_release_actions(source_project_name:, package_names:, target_project_names:)
      # Common users like Iggy don't have permission to modify openSUSE:Maintenance:0
      admin = User.default_admin

      bs_request = create(:bs_request_with_maintenance_release_actions,
                          creator: admin,
                          description: 'Request with release actions',
                          source_project_name: source_project_name,
                          package_names: package_names,
                          target_project_names: target_project_names)

      puts "* Request #{bs_request.number} with #{bs_request.bs_request_actions.size} maintenance release actions has been created."
      bs_request
    end

    def create_maintenance_setup
      iggy = User.find_by(login: 'Iggy')

      maintained_project1 = create_maintained_project('openSUSE:Leap:15.4')
      maintained_project2 = create_maintained_project('openSUSE:Backports:SLE-15-SP3')

      maintenance_project = create_maintenance_project

      update_project1 = create_update_project(maintained_project: maintained_project1, maintenance_project: maintenance_project)
      update_project2 = create_update_project(maintained_project: maintained_project2, maintenance_project: maintenance_project)

      # Create the first incident request (one action; not accepted; no patchinfo)
      update_project_branch = mimic_mbranch('bash')
      add_changes_to_update_project_branch(update_project_branch)

      create(:bs_request_with_maintenance_incident_actions,
             creator: iggy,
             description: 'Request with incident actions',
             source_package_names: ['bash'],
             target_releaseproject_names: [update_project1.name],
             source_project_name: update_project_branch.name,
             target_project_name: maintenance_project).tap do |bs_request|
        puts "* Request #{bs_request.number} with #{bs_request.bs_request_actions.size} maintenance incident actions has been created."
      end

      update_project_branch = mimic_mbranch('cacti')
      mimic_branch_maintenance(project_name: update_project1.name, package_name: 'cacti-spine', target_project_name: update_project_branch.name)
      mimic_branch_maintenance(project_name: update_project2.name, package_name: 'cacti-spine', target_project_name: update_project_branch.name)
      add_changes_to_update_project_branch(update_project_branch)
      mimic_patchinfo(update_project_branch.name)

      # Create the second incident request (many actions; not accepted; with patchinfo)
      create(:bs_request_with_maintenance_incident_actions,
             :with_patchinfo,
             creator: iggy,
             description: 'Request with incident actions',
             source_package_names: %w[cacti cacti-spine],
             target_releaseproject_names: [update_project1.name, update_project2.name],
             source_project_name: update_project_branch.name,
             target_project_name: maintenance_project).tap do |bs_request|
        puts "* Request #{bs_request.number} with #{bs_request.bs_request_actions.size} maintenance incident actions has been created."
      end

      # Create the third incident request (many actions; with patchinfo)
      create(:bs_request_with_maintenance_incident_actions,
             :with_patchinfo,
             :with_last_incident_accepted,
             creator: iggy,
             description: 'Request with incident actions',
             source_package_names: %w[cacti cacti-spine],
             target_releaseproject_names: [update_project1.name, update_project2.name],
             source_project_name: update_project_branch.name,
             target_project_name: maintenance_project).tap do |bs_request|
        puts "* Accepted Request #{bs_request.number} with #{bs_request.bs_request_actions.size} maintenance incident actions has been created."
      end

      # Open a request from a package that is not branched, but developed on an "official" project.
      # Simulate `osc maintenancerequest servers apache2 openSUSE:Leap:15.4:Update`
      create(:bs_request_with_maintenance_incident_actions,
             creator: iggy,
             description: 'Request with incident actions',
             source_package_names: ['apache2'],
             target_releaseproject_names: [update_project1.name],
             source_project_name: 'servers',
             target_project_name: maintenance_project.name).tap do |bs_request|
        puts "* Request #{bs_request.number} with #{bs_request.bs_request_actions.size} maintenance incident actions has been created."
      end

      # Create maintenance release request that asks for releasing the changes on openSUSE:Maintenance:0 to openSUSE:*:Update.
      create_request_with_maintenance_release_actions(source_project_name: 'openSUSE:Maintenance:0',
                                                      package_names: %w[cacti cacti-spine],
                                                      target_project_names: [update_project1.name, update_project2.name])
    end
  end
end
# rubocop:enable Metrics/ModuleLength
