class Workflow::Step::TriggerServices < Workflow::Step
  include Triggerable

  REQUIRED_KEYS = [:project, :package].freeze

  validate :validate_project_and_package_name

  def call(_options = {})
    @project_name = step_instructions[:project]
    @package_name = step_instructions[:package]

    set_project
    set_package(package_find_options: package_find_options)
    set_object_to_authorize
    set_multibuild_flavor

    Pundit.authorize(@token.user, @token, :trigger_service?)
    Backend::Api::Sources::Package.trigger_services(@project_name, @package_name, @token.user.login)
  end

  private

  def package_find_options
    { use_source: true, follow_project_links: false, follow_multibuild: false }
  end
end
