module RakeSupport
  def self.create_and_assign_project(project_name, user)
    create(:project, name: project_name).tap do |project|
      create(:relationship, project: project, user: user, role: Role.hashed['maintainer'])
    end
  end

  def self.find_or_create_project(project_name, user)
    project = Project.joins(:relationships)
                     .where(projects: { name: project_name }, relationships: { user: user }).first
    return project if project

    create_and_assign_project(project_name, user)
  end

  def self.copy_example_file(example_file)
    if File.exist?(example_file) && !ENV['FORCE_EXAMPLE_FILES']
      example_file = File.join(File.expand_path("#{File.dirname(__FILE__)}/../.."), example_file)
      puts "WARNING: You already have the config file #{example_file}, make sure it works with docker"
    else
      puts "Creating config/#{example_file} from config/#{example_file}.example"
      FileUtils.copy_file("#{example_file}.example", example_file)
    end
  end

  def self.request_for_staging(staging_project, maintainer_project, suffix)
    requester = create(:confirmed_user, login: "requester_#{suffix}")
    source_project = create(:project, name: "source_project_#{suffix}")
    target_package = create(:package, name: "target_package_#{suffix}", project: maintainer_project)
    source_package = create(:package, name: "source_package_#{suffix}", project: source_project)
    request = create(
      :bs_request_with_submit_action,
      state: :new,
      creator: requester,
      target_package: target_package,
      source_package: source_package,
      staging_project: staging_project
    )

    request.reviews.each { |review| review.change_state(:accepted, 'Accepted') }
  end

  def self.subscribe_to_all_notifications(user)
    create(:event_subscription_request_created, channel: :web, user: user, receiver_role: 'target_maintainer')
    create(:event_subscription_review_wanted, channel: 'web', user: user, receiver_role: 'reviewer')
    create(:event_subscription_request_statechange, channel: :web, user: user, receiver_role: 'target_maintainer')
    create(:event_subscription_request_statechange, channel: :web, user: user, receiver_role: 'source_maintainer')
    create(:event_subscription_comment_for_project, channel: :web, user: user, receiver_role: 'maintainer')
    create(:event_subscription_comment_for_package, channel: :web, user: user, receiver_role: 'maintainer')
    create(:event_subscription_comment_for_request, channel: :web, user: user, receiver_role: 'target_maintainer')
    create(:event_subscription_relationship_create, channel: :web, user: user, receiver_role: 'any_role')
    create(:event_subscription_relationship_delete, channel: :web, user: user, receiver_role: 'any_role')
    create(:event_subscription_report, channel: :web, user: user)
    create(:event_subscription_build_fail, channel: :web, user: user)

    create(:event_subscription_added_user_to_group, channel: :web, user: user)
    create(:event_subscription_removed_user_from_group, channel: :web, user: user)

    create(:event_subscription_workflow_run_fail, channel: :web, user: user, receiver_role: 'token_executor')

    user.groups.each do |group|
      create(:event_subscription_request_created, channel: :web, user: nil, group: group, receiver_role: 'target_maintainer')
      create(:event_subscription_review_wanted, channel: 'web', user: nil, group: group, receiver_role: 'reviewer')
      create(:event_subscription_request_statechange, channel: :web, user: nil, group: group, receiver_role: 'target_maintainer')
      create(:event_subscription_request_statechange, channel: :web, user: nil, group: group, receiver_role: 'source_maintainer')
      create(:event_subscription_comment_for_project, channel: :web, user: nil, group: group, receiver_role: 'maintainer')
      create(:event_subscription_comment_for_package, channel: :web, user: nil, group: group, receiver_role: 'maintainer')
      create(:event_subscription_comment_for_request, channel: :web, user: nil, group: group, receiver_role: 'target_maintainer')
      create(:event_subscription_relationship_create, channel: :web, user: nil, group: group, receiver_role: 'any_role')
      create(:event_subscription_relationship_delete, channel: :web, user: nil, group: group, receiver_role: 'any_role')
    end
  end
end
