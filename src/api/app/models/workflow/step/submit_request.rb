class Workflow::Step::SubmitRequest < Workflow::Step
  REQUIRED_KEYS = %i[source_project source_package target_project].freeze

  def call
    return unless valid?

    @request_numbers_and_state_for_artifacts = {}
    case
    when workflow_run.closed_merged_pull_request?, workflow_run.unlabeled_pull_request?
      revoke_submit_requests
    when workflow_run.updated_pull_request?
      supersede_previous_and_submit_request
    when workflow_run.new_pull_request?, workflow_run.reopened_pull_request?, workflow_run.push_event?, workflow_run.tag_push_event?, workflow_run.labeled_pull_request?
      submit_package
    end
  end

  def artifact
    return { @bs_request.state => @bs_request.number } if @bs_request

    {}
  end

  private

  def bs_request_description
    step_instructions[:description] || workflow_run.event_source_message
  end

  def submit_package
    # let possible running source services finish, before submitting the sources
    Backend::Api::Sources::Package.wait_service(step_instructions[:source_project], step_instructions[:source_package])
    bs_request_action = BsRequestAction.new(source_project: step_instructions[:source_project],
                                            source_package: step_instructions[:source_package],
                                            target_project: step_instructions[:target_project],
                                            target_package: step_instructions[:target_package],
                                            source_rev: source_package_revision,
                                            type: 'submit')
    @bs_request = BsRequest.new(bs_request_actions: [bs_request_action],
                                description: bs_request_description)
    Pundit.authorize(@token.executor, @bs_request, :create?)
    @bs_request.save!

    Workflows::ScmEventSubscriptionCreator.new(token, workflow_run, @bs_request).call
    SCMStatusReporter.new(event_payload: { number: @bs_request.number, state: @bs_request.state },
                          event_subscription_payload: workflow_run.payload,
                          scm_token: @token.scm_token,
                          workflow_run: workflow_run,
                          event_type: 'Event::RequestStatechange').call
    @bs_request
  end

  def supersede_previous_and_submit_request
    # Fetch current open submit request which are going to be superseded
    # after the new sumbit request is created
    requests_to_be_superseded = submit_requests_with_same_target_and_source
    new_submit_request = submit_package

    requests_to_be_superseded.each do |submit_request|
      # Authorization happens on model level
      request = BsRequest.find_by_number!(submit_request.number)
      request.change_state(newstate: 'superseded',
                           reason: "Superseded by request #{new_submit_request.number}",
                           superseded_by: new_submit_request.number)
      (@request_numbers_and_state_for_artifacts[request.state.to_s] ||= []) << request.number
    end
  end

  def revoke_submit_requests
    submit_requests_with_same_target_and_source.each do |submit_request|
      Pundit.authorize(@token.executor, submit_request, :revoke_request?)

      submit_request.change_state(newstate: 'revoked', comment: "Revoke as #{workflow_run.event_source_url} got closed")
      (@request_numbers_and_state_for_artifacts[submit_request.state.to_s] ||= []) << submit_request.number
    end
  end

  def submit_requests_with_same_target_and_source
    BsRequest.list({ project: step_instructions[:target_project],
                     source_project: step_instructions[:source_project],
                     package: step_instructions[:source_package],
                     types: 'submit', states: %w[new review declined] })
  end

  def source_package
    Package.get_by_project_and_name(step_instructions[:source_project], step_instructions[:source_package], follow_multibuild: true)
  end

  def source_package_revision
    source_package.rev
  end
end
