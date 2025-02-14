class Workflow::Step::TriggerServices < Workflow::Step
  include Triggerable
  include Workflow::Step::Errors

  REQUIRED_KEYS = %i[project package].freeze

  def call
    return if workflow_run.closed_merged_pull_request? || workflow_run.reopened_pull_request? || workflow_run.unlabeled_pull_request?

    @project_name = step_instructions[:project]
    @package_name = step_instructions[:package]

    set_project
    set_package(package_find_options: package_find_options)
    set_object_to_authorize
    set_multibuild_flavor

    Pundit.authorize(@token.executor, @token.object_to_authorize, :update?)

    begin
      Backend::Api::Sources::Package.trigger_services(@project_name, @package_name, @token.executor.login, trigger_service_comment)
    rescue Backend::NotFoundError => e
      raise NoSourceServiceDefined, "Package #{@project_name}/#{@package_name} does not have a source service defined: #{e.summary}"
    end

    Workflows::ScmEventSubscriptionCreator.new(token, workflow_run, @package).call
  end

  private

  def package_find_options
    { follow_project_links: false }
  end

  # Examples of comments:
  # "Service triggered by a workflow token via $scm PR/MR $number ($event)"
  # "Service triggered by the '$token' token via $scm push $sha on $tag || $branch"
  def trigger_service_comment
    'Service triggered by ' \
      "#{@token.description.blank? ? 'a workflow token ' : "the '#{@token.description}' token "}" \
      "via #{workflow_run.scm_vendor.titleize} " \
      "#{details}."
  end

  def details
    case workflow_run.hook_event
    when 'pull_request', 'Merge Request Hook'
      "PR/MR ##{workflow_run.pr_number} (#{workflow_run.hook_event})"
    when 'push', 'Push Hook'
      push_details
    when 'Tag Push Hook'
      "push #{workflow_run.commit_sha&.slice(0, SHORT_COMMIT_SHA_LENGTH)} on #{workflow_run.tag_name}"
    end
  end

  def push_details
    if workflow_run.scm_vendor == 'github' && workflow_run.payload[:ref].start_with?('refs/tags')
      "push #{workflow_run.commit_sha&.slice(0, SHORT_COMMIT_SHA_LENGTH)} on #{workflow_run.tag_name}"
    else
      "push #{workflow_run.commit_sha&.slice(0, SHORT_COMMIT_SHA_LENGTH)} on #{workflow_run.target_branch}"
    end
  end
end
