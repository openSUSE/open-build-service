class GitlabStatusReporter < SCMStatusReporter
  def call
    gitlab_client = Gitlab.client(endpoint: "#{@event_subscription_payload[:api_endpoint]}/api/v4",
                                  private_token: @scm_token)
    # https://docs.gitlab.com/ce/api/commits.html#post-the-build-status-to-a-commit
    gitlab_client.update_commit_status(@event_subscription_payload[:project_id],
                                       @event_subscription_payload[:commit_sha],
                                       @state,
                                       status_options)
    if @workflow_run.present?
      @workflow_run.save_scm_report_success(request_context)
      RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=success,scm=#{@event_subscription_payload[:scm]} value=1")
    end
  rescue Gitlab::Error::Error => e
    rescue_with_handler(e) || raise(e)
    RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=fail,scm=#{@event_subscription_payload[:scm]},exception=#{e} value=1") if @workflow_run.present?
  end

  private

  def scm_final_state(event_type)
    case event_type
    when 'Event::BuildFail'
      'failed'
    when 'Event::BuildSuccess'
      'success'
    else
      'pending'
    end
  end
end
