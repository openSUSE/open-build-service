class Workflow::Step::TriggerServices < Workflow::Step
  include Triggerable
  include Workflow::Step::Errors

  REQUIRED_KEYS = [:project, :package].freeze

  validate :validate_project_and_package_name

  def call
    @project_name = step_instructions[:project]
    @package_name = step_instructions[:package]

    set_project
    set_package(package_find_options: package_find_options)
    set_object_to_authorize
    set_multibuild_flavor

    Pundit.authorize(@token.executor, @token, :trigger_service?)

    begin
      Backend::Api::Sources::Package.trigger_services(@project_name, @package_name, @token.executor.login, trigger_service_comment)
    rescue Backend::NotFoundError => e
      raise NoSourceServiceDefined, "Package #{@project_name}/#{@package_name} does not have a source service defined: #{e.summary}"
    end
  end

  private

  def package_find_options
    { use_source: true, follow_project_links: false, follow_multibuild: false }
  end

  # Examples of comments:
  # "Service triggered by a workflow token via $scm PR/MR $number ($event)"
  # "Service triggered by the '$token' token via $scm push $sha on $tag || $branch"
  def trigger_service_comment
    'Service triggered by ' \
      "#{@token.description.blank? ? 'a workflow token ' : "the '#{@token.description}' token "}" \
      "via #{@scm_webhook.payload[:scm].titleize} " \
      "#{details}."
  end

  def details
    case @scm_webhook.payload[:event]
    when 'pull_request', 'Merge Request Hook'
      "PR/MR ##{@scm_webhook.payload[:pr_number]} (#{@scm_webhook.payload[:event]})"
    when 'push', 'Push Hook'
      push_details
    when 'Tag Push Hook'
      "push #{@scm_webhook.payload[:commit_sha]&.slice(0, SHORT_COMMIT_SHA_LENGTH)} on #{@scm_webhook.payload[:tag_name]}"
    end
  end

  def push_details
    if @scm_webhook.payload[:scm] == 'github' && @scm_webhook.payload[:ref].start_with?('refs/tags')
      "push #{@scm_webhook.payload[:commit_sha]&.slice(0, SHORT_COMMIT_SHA_LENGTH)} on #{@scm_webhook.payload[:tag_name]}"
    else
      "push #{@scm_webhook.payload[:commit_sha]&.slice(0, SHORT_COMMIT_SHA_LENGTH)} on #{@scm_webhook.payload[:target_branch]}"
    end
  end
end
