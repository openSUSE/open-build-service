BASE_API_URL = 'https://api.opensuse.org'.freeze

namespace :dev do
  namespace :requests do
    # Run this task with: rails dev:requests:multiple_actions_request
    desc 'Creates a request with multiple actions'
    task :multiple_actions_request, [:repetitions] => :development_environment do |_t, args|
      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i

      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      repetitions.times do
        admin = User.default_admin
        User.session = admin
        iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')

        # Set target project and package
        target_project = Project.find_by(name: 'openSUSE:Factory') || create(:project, name: 'openSUSE:Factory') # openSUSE:Factory
        target_package_a = Package.where(name: 'package_a', project: target_project).first ||
                           create(:package_with_files, name: 'package_a', project: target_project)

        # Simulate the branching of source project by Iggy, then it modifies some packages
        source_project = RakeSupport.find_or_create_project(iggy.branch_project_name(target_project.name), iggy) # home:Iggy:branches:openSUSE:Factory
        source_package_a = Package.where(name: 'package_a', project: source_project).first ||
                           create(:package_with_files, name: 'package_a', project: source_project, changes_file_content: '- Fixes boo#2222222 and CVE-2011-2222')

        # Create request to submit new files to the target package A
        request = create(
          :bs_request_with_submit_action,
          creator: iggy,
          target_project: target_project,
          target_package: target_package_a,
          source_project: source_project,
          source_package: source_package_a
        )

        target_package_b = Package.where(name: 'package_b', project: target_project).first ||
                           create(:package, name: 'package_b', project: target_project)

        # Create more actions to submit new files from different packages to package_b
        ('b'..'z').each_with_index do |char, index|
          figure = (index + 1).to_s.rjust(2, '0') # Generate the last two figures for the issue code
          changes_file_content = "- Fixes boo#11111#{figure} CVE-2011-11#{figure}"

          source_package = Package.where(name: "package_#{char}", project: source_project).first ||
                           create(:package_with_files, name: "package_#{char}", project: source_project, changes_file_content: changes_file_content)

          action_attributes = {
            source_package: source_package,
            source_project: source_project,
            target_project: target_project,
            target_package: target_package_b
          }
          bs_req_action = build(:bs_request_action, action_attributes.merge(type: 'submit', bs_request: request))
          bs_req_action.save!
        end

        # Create an action to add role
        action_attributes = {
          target_project: target_project,
          target_package: target_package_a,
          person_name: User.last.login,
          role: Role.find_by_title!('maintainer'),
          type: 'add_role',
          bs_request: request
        }
        bs_req_action = build(:bs_request_action, action_attributes)
        bs_req_action.save!

        # Create an action to set a user as bugowner
        action_attributes = {
          target_project: target_project,
          target_package: target_package_b,
          person_name: 'user_1',
          type: 'set_bugowner',
          bs_request: request
        }
        bs_req_action = build(:bs_request_action, action_attributes)
        bs_req_action.save!

        # Create an action to set a group as bugowner
        action_attributes = {
          target_project: target_project,
          target_package: target_package_a,
          group_name: 'group_1',
          type: 'set_bugowner',
          bs_request: request
        }
        bs_req_action = build(:bs_request_action, action_attributes)
        bs_req_action.save!

        create(:bs_request_action_delete,
               target_project: target_project,
               bs_request: request)

        create(:bs_request_action_delete,
               target_project: target_project,
               target_package: target_package_a,
               bs_request: request)

        # Create an action to change devel

        # Package to be developed in another place (target)
        # target_project -> openSUSE:Factory
        apache2_factory = Package.find_by_project_and_name('openSUSE:Factory', 'apache2')

        # Current devel package
        servers_project = Project.find_by(name: 'servers') || create(:project, name: 'servers')
        apache2_servers = Package.find_by_project_and_name(servers_project.name, 'apache2') || create(:package_with_file, project: servers_project, name: 'apache2')

        # Future devel package (source)
        # source_project -> home:Iggy:branches:openSUSE:Factory
        Package.find_by_project_and_name(source_project.name, 'apache2') || create(:package, project: source_project, name: 'apache2')

        # Set development package
        apache2_factory.update(develpackage: apache2_servers)

        action_attributes = {
          source_project_name: source_project.name,
          target_project_name: target_project.name,
          target_package_name: apache2_factory.name,
          bs_request: request
        }
        bs_req_action = build(:bs_request_action_change_devel, action_attributes)
        bs_req_action.save!

        puts "* Request #{request.number} contains multiple actions and mentioned issues."
        puts 'To start the builds confirm or perfom the following steps:'
        puts '- Create the interconnect with openSUSE.org'
        puts "- Create a couple of repositories in project #{source_project.name}"
      end
    end

    # Creates a request with two actions of the same type: 'submit'.
    desc 'Creates a request with only submit actions and some diffs'
    task :request_with_multiple_submit_actions_builds_and_diffs, %i[repetitions actions_count] => :development_environment do |_t, args|
      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i

      args.with_defaults(actions_count: 2)
      actions_count = args.actions_count.to_i

      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      User.session = iggy
      admin = User.default_admin
      iggy_home_project = RakeSupport.find_or_create_project(iggy.home_project_name, iggy)
      home_admin_project = RakeSupport.find_or_create_project(admin.home_project_name, admin)

      repetitions.times do |repetition|
        source_package_name = "source_package_with_multiple_submit_request_and_diff_#{Time.now.to_i}_#{repetition}"
        source_package =
          Package.find_by_project_and_name(iggy_home_project, source_package_name) || create(:package_with_files,
                                                                                             project: iggy_home_project,
                                                                                             name: source_package_name,
                                                                                             file_content: '# New content')

        target_package_name = "target_package_with_diff_#{Time.now.to_i - 1.second}_#{repetition}"
        target_package =
          Package.find_by_project_and_name(home_admin_project, target_package_name) || create(:package_with_files,
                                                                                              project: home_admin_project,
                                                                                              name: target_package_name,
                                                                                              file_content: '# This will be replaced')

        bs_request = create(:bs_request_with_submit_action,
                            creator: iggy,
                            source_project: iggy_home_project,
                            source_package: source_package,
                            target_project: home_admin_project,
                            target_package: target_package)

        (1..actions_count).each do |action_index|
          another_source_package_name = "another_source_package_with_multiple_submit_request_and_diff_#{Time.now.to_i}_#{repetition}_#{action_index}"
          another_source_package =
            Package.find_by_project_and_name(iggy_home_project.name, another_source_package_name) ||
            create(:package_with_files,
                   project: iggy_home_project,
                   name: another_source_package_name,
                   file_content: '# New content')

          another_target_package_name = "another_package_with_diff_#{Time.now.to_i}_#{repetition}_#{action_index}"
          another_target_package =
            Package.find_by_project_and_name(home_admin_project, another_target_package_name) || create(:package_with_files,
                                                                                                        project: home_admin_project,
                                                                                                        name: another_target_package_name,
                                                                                                        file_content: '# This will be replaced')

          create(:bs_request_action_submit_with_diff,
                 creator: iggy,
                 source_project_name: iggy_home_project.name,
                 source_package_name: another_source_package.name,
                 target_project_name: home_admin_project.name,
                 target_package_name: another_target_package.name,
                 bs_request: bs_request)
        end

        puts "* Request with #{actions_count} submit actions, builds, diffs and rpm lints."
        puts "  See http://localhost:3000/request/show/#{bs_request.number}."
        puts '  To start the builds confirm or perfom the following steps:'
        puts '  - Create the interconnect with openSUSE.org'
        puts "  - Create a couple of repositories in project #{iggy_home_project.name}"
      end
    end

    # Run this task with: rails dev:requests:request_with_delete_action
    desc 'Creates a request with a delete action'
    task :request_with_delete_action, [:repetitions] => :development_environment do |_t, args|
      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i

      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      admin = User.default_admin
      home_admin_project = RakeSupport.find_or_create_project(admin.home_project_name, admin)

      repetitions.times do |repetition|
        target_package = create(:package, project: home_admin_project, name: "#{Faker::Lorem.word}_#{Time.now.to_i}_#{repetition}")
        request = create(:delete_bs_request, target_package: target_package, creator: iggy)

        puts "* Request with delete action #{request.number} has been created."
      end
    end

    desc 'Copy 10 submit requests from openSUSE:Factory'
    task copy_requests_from_opensuse_factory: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      # List of users created as a result of the `copy_requests_from_opensuse_factory` task.
      @users_list = {}
      admin = User.default_admin
      admin.run_as do
        # Setup interconnect
        remote_proj = Project.find_or_create_by(name: 'openSUSE.org', remoteurl: 'https://api.opensuse.org/public')
        remote_proj.store
        FetchRemoteDistributionsJob.perform_now

        clone_project(project_name: 'openSUSE:Factory')

        # Get the list of requests from openSUSE:Factory
        url = "#{BASE_API_URL}/search/request"
        params = { match: "target/@project='openSUSE:Factory' and state/@name='review' and action/@type='submit'", project: 'openSUSE:Factory', limit: '10', withhistory: '1', withfullhistory: '1' }
        # Get the total number of submit requests
        temp_request = make_api_request(url: url, params: params.merge(limit: '1'))
        offset = Xmlhash.parse(temp_request)['matches'].to_i / 2
        # Take subset of requests from middle
        request = make_api_request(url: url, params: params.merge(offset: offset.to_s))
        requests_list = Xmlhash.parse(request)
        print_message 'Successfully got the requests list'

        requests_list['request'].each do |req|
          branch_package(
            source_project_name: 'openSUSE.org:openSUSE:Factory',
            source_package_name: req['action']['target']['package'],
            target_project: 'openSUSE:Factory'
          )

          find_user(req['creator']) if req['creator']
          clone_project(project_name: req['action']['source']['project'])
          branch_package(
            source_project_name: "openSUSE.org:#{req['action']['source']['project']}",
            source_package_name: req['action']['source']['package'],
            target_project: req['action']['source']['project']
          )

          # Don't copy existing requests
          bs_request = BsRequest.where(description: "Bs request ##{req['id']}").last
          if bs_request.present?
            print_message("Duplicate request #{bs_request.number}")
            next
          end

          request_params = {
            bs_request: {
              description: "Bs request ##{req['id']}",
              creator: alias_for_login(req['creator']),
              state: req['state']['name']
            },
            bs_request_actions: {
              target_project: 'openSUSE:Factory',
              source_project: req['action']['source']['project'],
              source_package: req['action']['source']['package'],
              type: req['action']['type']
            }
          }
          bs_request = create_bs_request(request_params)
          create_reviews(bs_request: bs_request, reviews: req['review'])
        end
      end
    end

    def branch_package(source_project_name:, source_package_name:, target_project:)
      branch_params = {
        project: source_project_name,
        package: source_package_name,
        target_project: target_project,
        force: 1
      }

      begin
        BranchPackage.new(branch_params).branch
      rescue Backend::NotFoundError
        # do nothing
      end
    end

    def create_bs_request(params)
      bs_request = BsRequest.new(params[:bs_request])
      bs_request.bs_request_actions.new(params[:bs_request_actions])

      bs_request.save!
      print_message("Successfully created request##{bs_request.number}")

      bs_request
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def create_reviews(bs_request:, reviews:)
      review_params = reviews.filter_map do |params|
        next if params['by_project'] && params['by_project'].match?('openSUSE:Factory:Staging')

        reviewer = find_user(params['who'] || params['by_user']).login if params['who'] || params['by_user']
        user_id = find_user(params['by_user']).id if params['by_user']

        {
          review: {
            reviewer: reviewer,
            by_user: alias_for_login(params['by_user']),
            state: params['state'],
            reason: params['comment'],
            by_group: params['by_group'],
            by_project: params['by_project'],
            by_package: params['by_package'],
            user_id: user_id,
            group_id: find_group(params['by_group']).try(:id),
            project_id: find_project(params['by_project']).try(:id),
            package_id: find_package(params['by_project'], params['by_package']).try(:id)
          },
          history_elements: prepare_history_elements_data(params['history'])
        }
      end

      bs_request.reviews.destroy_all
      review_params.each do |params|
        review = bs_request.reviews.create!(params[:review])
        create_history_elements(review, params[:history_elements])
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def create_history_elements(review, params)
      case review.state
      when :accepted
        klass = HistoryElement::ReviewAccepted
      when :declined
        klass = HistoryElement::ReviewDeclined
      end
      params.each do |param|
        klass.create!(op_object_id: review.id, user_id: param[:user_id], comment: param[:comment])
      end
    end

    def prepare_history_elements_data(params)
      return [] if params.nil?

      if params.is_a?(Array)
        params.map do |param|
          user_id = find_user(param['who']).id if param['who']
          {
            user_id: user_id,
            description: param['description'],
            comment: param['comment']
          }
        end
      else
        user_id = find_user(params['who']).id if params['who']
        [{
          user_id: user_id,
          description: params['description'],
          comment: params['comment']
        }]
      end
    end

    def clone_project(project_name:)
      project = Project.find_or_create_by(name: project_name)
      config = make_api_request(url: "#{BASE_API_URL}/source/#{project.name}/_config")
      clone_prj_configs(config: config, project: project, comment: "Cloned from #{project.name}")

      request = make_api_request(url: "#{BASE_API_URL}/source/#{project.name}/_meta")
      request_data = Xmlhash.parse(request)

      create_users_and_groups_from_meta(request_data: request_data)
      create_repositories_from_meta(request_data: request_data, target_project: project)
      clone_meta(meta: request, comment: "Cloned _meta from #{project.name}", project: project)
    end

    def clone_meta(meta:, comment:, project:)
      params = ActionController::Parameters.new({ meta: meta, comment: comment, project: project.name })
      meta_validator = MetaControllerService::MetaXMLValidator.new(params)
      meta_validator.call

      [meta_validator.request_data['person']].flatten.each do |person|
        person['userid'] = find_user(person['userid']).login
      end
      updater = MetaControllerService::ProjectUpdater.new(project: project, request_data: meta_validator.request_data).call
      print_message(updater.errors) if updater.errors
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def create_repositories_from_meta(request_data:, target_project:)
      [request_data['repository']].flatten.each do |repository|
        if repository['releasetarget'] && repository['releasetarget']['project']
          project = Project.find_or_create_by(name: repository['releasetarget']['project'])
          proj_repo = project.repositories.find_or_initialize_by(name: repository['releasetarget']['repository'])
        elsif repository['path'].is_a?(Array)
          repository['path'].each do |path|
            project = Project.find_or_create_by(name: path['project'])
            proj_repo = project.repositories.find_or_initialize_by(name: path['repository'])

            target_repo = repository['name']
            target_repository = Repository.find_by_project_and_name(target_project.name, target_repo)
            target_repository = create(:repository, project: target_project, name: target_repo) if target_repository.nil?
            proj_repo.path_elements.find_or_initialize_by(link: target_repository)

            if repository['arch'].is_a?(Array)
              repository['arch'].each do |architecture|
                proj_repo.repository_architectures.find_or_initialize_by(architecture: Architecture.find_by(name: architecture))
              end
            else
              proj_repo.repository_architectures.find_or_initialize_by(architecture: Architecture.find_by(name: repository['arch']))
            end
            proj_repo.save!
            project.store(comment: "Added #{proj_repo.name} repository")
          end

          next
        elsif repository['path']
          project = Project.find_or_create_by(name: repository['path']['project'])
          proj_repo = project.repositories.find_or_initialize_by(name: repository['path']['repository'])
        else
          next
        end
        target_repo = repository['name']
        target_repository = Repository.find_by_project_and_name(target_project.name, target_repo)
        target_repository = create(:repository, project: target_project, name: target_repo) if target_repository.nil?
        proj_repo.path_elements.find_or_initialize_by(link: target_repository)

        if repository['arch'].is_a?(Array)
          repository['arch'].each do |architecture|
            proj_repo.repository_architectures.find_or_initialize_by(architecture: Architecture.find_by(name: architecture))
          end
        elsif repository['arch']
          proj_repo.repository_architectures.find_or_initialize_by(architecture: Architecture.find_by(name: repository['arch']))
        end

        proj_repo.save!
        project.store(comment: "Added #{proj_repo.name} repository")
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def create_users_and_groups_from_meta(request_data:)
      # create users
      if request_data['person'].present?
        [request_data['person']].flatten.each do |person|
          find_user(person['userid']) if person['userid']
        end
      end

      return if request_data['group'].nil?

      if request_data['group'].is_a?(Array)
        request_data['group'].each do |group|
          next if Group.find_by(title: group['groupid'])

          create(:group, title: group['groupid'])
        end
      else
        group = Group.find_by(title: request_data['group']['groupid'])

        create(:group, title: request_data['group']['groupid']) if group.nil?
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def find_user(login)
      alias_for_login(login)
      user = User.find_by_login(@users_list[login])
      user ||= create(:confirmed_user, login: @users_list[login])

      user
    end

    def alias_for_login(login = nil)
      return if login.blank?

      @users_list[login] ||= Faker::Alphanumeric.alpha(number: 10)
    end

    def find_group(title)
      return if title.nil?

      Group.find_or_create_by!(title: title)
    end

    def find_project(project_name)
      return if project_name.nil?

      Project.find_or_create_by(name: project_name)
    end

    def find_package(project_name, package_name)
      return if project_name.nil? || package_name.nil?

      package = Package.find_by_project_and_name(project_name, package_name)
      return package if package

      project = Project.find_or_create_by(name: project_name)
      create(:package, name: package_name, project: project)
    end

    def clone_prj_configs(config:, comment:, project:)
      project.config.save({ user: User.session!.login, comment: comment }, config)
    end

    def make_api_request(url:, params: {}, headers: { 'Content-Type' => 'application/xml' })
      username = ''
      password = ''

      abort("#{'=' * 50}\nusername or password not present.") unless username.present? && password.present?

      conn = Faraday.new(
        url: url,
        params: params,
        headers: headers
      )
      conn.set_basic_auth(username, password)
      request = conn.get

      request.body
    end

    def print_message(message)
      puts '=' * 50
      puts message
    end
  end
end
