class Workflow::Step::LinkPackageStep < Workflow::Step
  include ScmSyncEnabledStep

  REQUIRED_KEYS = [:source_project, :source_package, :target_project].freeze

  validate :validate_source_project_and_package_name

  def call
    return unless valid?

    link_package
  end

  private

  def link_package
    create_target_package if webhook_event_for_linking_or_branching?

    scm_synced? ? set_scmsync_on_target_package : add_branch_request_file(package: target_package)

    # SCMs don't support statuses for tags, so we don't need to report back in this case
    create_or_update_subscriptions(target_package) unless scm_webhook.tag_push_event?

    target_package
  end

  def target_project_base_name
    step_instructions[:target_project]
  end

  def target_project
    Project.find_by(name: target_project_name)
  end

  def create_target_package
    create_project_and_package
    return if scm_synced?

    create_project_services
    create_link
  end

  def create_project_and_package
    check_source_access

    raise PackageAlreadyExists, "Can not link package. The package #{target_package_name} already exists." if target_package.present?

    if target_project.nil?
      project = Project.new(name: target_project_name)
      Pundit.authorize(@token.executor, project, :create?)

      project.save!
      project.commit_user = User.session
      project.relationships.create!(user: User.session, role: Role.find_by_title('maintainer'))
      project.store
    end

    Pundit.authorize(@token.executor, target_project, :update?)
    target_project.packages.create(name: target_package_name)
  end

  # Will raise an exception if the source package is not accesible
  def check_source_access
    return if remote_source?

    Package.get_by_project_and_name(source_project_name, source_package_name)
  end

  # NOTE: the next lines are a temporary fix the allow the service to run in a linked package. A project service is needed.
  def create_project_services
    service_file = ProjectServiceFile.new(project_name: target_project)
    service_file.save!({}, special_package_file_content)
  end

  def special_package_file_content
    <<~XML
      <services>
        <service name="format_spec_file" mode="localonly"/>
      </services>
    XML
  end

  def create_link
    Backend::Api::Sources::Package.write_link(target_project_name,
                                              target_package_name,
                                              @token.executor,
                                              link_xml(project: source_project_name, package: source_package_name))

    target_package
  end

  def link_xml(opts = {})
    # "<link package=\"foo\" project=\"bar\" />"
    Nokogiri::XML::Builder.new { |x| x.link(opts) }.doc.root.to_s
  end
end
