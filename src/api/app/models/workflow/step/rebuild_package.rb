class Workflow::Step::RebuildPackage < Workflow::Step
  include Triggerable

  REQUIRED_KEYS = [:project, :package].freeze

  attr_reader :project_name, :package_name

  validate :validate_project_and_package_name

  def call
    return unless valid?

    # Call Triggerable method to set all the elements needed for rebuilding
    set_project_name
    set_package_name
    set_project
    set_package(package_find_options: package_find_options)
    set_object_to_authorize
    set_multibuild_flavor

    Pundit.authorize(@token.executor, @token, :rebuild?)
    rebuild_package
  end

  def set_project_name
    @project_name = step_instructions[:project]
  end

  def set_package_name
    @package_name = step_instructions[:package]
  end

  private

  def package_find_options
    { use_source: false, follow_project_links: true, follow_multibuild: true }
  end

  def rebuild_package
    Backend::Api::Sources::Package.rebuild(project_name, package_name)
  end
end
