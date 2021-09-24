class Workflow::Step::LinkPackageStep < ::Workflow::Step
  REQUIRED_KEYS = [:source_project, :source_package, :target_project].freeze

  def call(options = {})
    return unless valid?

    workflow_filters = options.fetch(:workflow_filters, {})
    link_package(workflow_filters)
  end

  private

  def link_package(workflow_filters = {})
    create_target_package if scm_webhook.new_pull_request? || (scm_webhook.updated_pull_request? && target_package.blank?)

    create_or_update_subscriptions(target_package, workflow_filters)
    add_branch_request_file(package: target_package)
    report_to_scm(workflow_filters)
    target_package
  end

  def target_project
    Project.find_by(name: target_project_name)
  end

  def create_target_package
    create_project_and_package
    create_special_package
    create_link
  end

  def create_project_and_package
    check_source_access

    raise PackageAlreadyExists, "Can not link package. The package #{target_package_name} already exists." if target_package.present?

    if target_project.nil?
      project = Project.new(name: target_project_name)
      Pundit.authorize(@token.user, project, :create?)

      project.save!
      project.commit_user = User.session
      project.relationships.create!(user: User.session, role: Role.find_by_title('maintainer'))
      project.store
    end

    Pundit.authorize(@token.user, target_project, :update?)
    target_project.packages.create(name: target_package_name)
  end

  # Will raise an exception if the source package is not accesible
  def check_source_access
    return if remote_source?

    Package.get_by_project_and_name(source_project_name, source_package_name)
  end

  # NOTE: the next lines are a temporary fix the allow the service to run in a linked package. A project service is needed.
  def create_special_package
    return if Package.find_by_project_and_name(target_project, '_project')

    special_package = target_project.packages.create(name: '_project')
    special_package.save_file({ file: special_package_file_content, filename: '_service' })
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
                                              @token.user,
                                              link_xml(project: source_project_name, package: source_package_name))

    target_package
  end

  def link_xml(opts = {})
    # "<link package=\"foo\" project=\"bar\" />"
    Nokogiri::XML::Builder.new { |x| x.link(opts) }.doc.root.to_s
  end
end
