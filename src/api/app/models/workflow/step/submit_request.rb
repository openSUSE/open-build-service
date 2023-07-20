class Workflow::Step::SubmitRequest < Workflow::Step
  REQUIRED_KEYS = [:source_project, :source_package, :target_project]
  validate :validate_source_project_and_package_name

  def call
    return unless valid?
    @request_numbers_and_state_for_artifacts = {}

    if scm_webhook.closed_merged_pull_request?
      revoke_submit_requests
      collect_artifacts
      return
    end
    # Fetch current open submit request which are going to be superseded
    # after the new sumbit request is created
    requests_to_be_superseded = submit_requests_with_same_target_and_source
    # TODO: wait for source services to finish before submitting
    if scm_webhook.new_pull_request? || scm_webhook.updated_pull_request? || scm_webhook.reopened_pull_request? || scm_webhook.push_event? || scm_webhook.tag_push_event?
      new_submit_request = submit_package
    end

    if scm_webhook.updated_pull_request?
      supersede_previous_submit_requests(new_submit_request: new_submit_request,
                                         requests_to_be_superseded: requests_to_be_superseded)
    end
    collect_artifacts
  end

  private

  def collect_artifacts
    Workflows::ArtifactsCollector.new(step: self, workflow_run_id: workflow_run.id, request_numbers_and_state_for_artifacts: @request_numbers_and_state_for_artifacts).call
  end

  def submit_package
    bs_request_action = BsRequestAction.new(source_project: step_instructions[:source_project],
                                            source_package: step_instructions[:source_package],
                                            target_project: step_instructions[:target_project],
                                            target_package: step_instructions[:target_package],
                                            source_rev: source_package_revision,
                                            type: 'submit')
    bs_request = BsRequest.new(bs_request_actions: [bs_request_action],
                               description: step_instructions[:description])
    Pundit.authorize(@token.executor, bs_request, :create?)

    begin
      bs_request.save!
    rescue MaintenanceHelper::MissingAction
      raise 'Unable to submit, sources are unchanged'
    rescue Project::Errors::UnknownObjectError
      raise "Unable to submit: The source of package #{source_project_name}/#{source_package_name} is broken"
    rescue APIError, ActiveRecord::RecordInvalid => e
      raise e.message
    rescue Backend::Error => e
      raise e.summary
    end

    create_or_update_subscriptions(bs_request: bs_request)
    (@request_numbers_and_state_for_artifacts["#{bs_request.state}"] ||= []) << bs_request.number
    bs_request
  end

  def supersede_previous_submit_requests(new_submit_request:, requests_to_be_superseded:)
    return if requests_to_be_superseded.blank?

    requests_to_be_superseded.each do |submit_request|
      # Authorization happens on model level
      request = BsRequest.find_by_number!(submit_request.number)
      request.change_state(newstate: 'superseded',
                    reason: "Superseded by request #{new_submit_request.number}",
                    superseded_by: new_submit_request.number)
      (@request_numbers_and_state_for_artifacts["#{request.state}"] ||= []) << request.number
    end
  end

  def revoke_submit_requests
    return if submit_requests_with_same_target_and_source.blank?

    submit_requests_with_same_target_and_source.each do |submit_request|
      next unless Pundit.authorize(@token.executor, submit_request, :revoke_request?)

      # TODO: Proper comment
      submit_request.change_state(newstate: 'revoked', comment: "Revoked through SCM/CI integration")
      (@request_numbers_and_state_for_artifacts["#{submit_request.state}"] ||= []) << submit_request.number
    end
  end

  def submit_requests_with_same_target_and_source
    BsRequest.list({ project: step_instructions[:target_project],
                     source_project: step_instructions[:source_project],
                     package: step_instructions[:source_package],
                     types: 'submit', states: ['new', 'review', 'declined']
                  })
  end

  def source_package
    Package.get_by_project_and_name(source_project_name, source_package_name, follow_multibuild: true)
  rescue Project::Errors::UnknownObjectError, Package::Errors::UnknownObjectError
    # We rely on Package.get_by_project_and_name since it's the only way to work with multibuild packages.
    raise "The source project or package '#{source_project_name}/#{source_package_name}' does not exist"
  end

  def source_package_revision
    source_package.rev
  end

  def create_or_update_subscriptions(bs_request:)
    subscription = EventSubscription.find_or_create_by!(eventtype: 'Event::RequestStatechange',
                                                        receiver_role: 'reader', # We pass a valid value, but we don't need this.
                                                        user: @token.executor,
                                                        channel: 'scm',
                                                        enabled: true,
                                                        token: @token,
                                                        workflow_run: workflow_run,
                                                        bs_request: bs_request)
    subscription.update!(payload: scm_webhook.payload)
  end
end
