class SCMWebhookEventValidator < ActiveModel::Validator
  ALLOWED_GITHUB_AND_GITEA_EVENTS = ['pull_request', 'push', 'ping'].freeze
  ALLOWED_GITLAB_EVENTS = ['Merge Request Hook', 'Push Hook', 'Tag Push Hook'].freeze

  def validate(record)
    @record = record

    return if valid_github_or_gitea_event? || valid_gitlab_event?

    # FIXME: This error message is wrong when the SCM isn't supported. This is an edge case, somebody most probably fiddled with the payload.
    @record.errors.add(:base, 'Event not supported.')
  end

  private

  def valid_github_or_gitea_event?
    return false unless ['github', 'gitea'].include?(@record.payload[:scm])
    return false unless ALLOWED_GITHUB_AND_GITEA_EVENTS.include?(@record.payload[:event])

    case @record.payload[:event]
    when 'pull_request'
      return true if SCMWebhook::ALLOWED_PULL_REQUEST_ACTIONS.include?(@record.payload[:action])

      @record.errors.add(:base, 'Pull request action not supported.')
    when 'push'
      valid_push_event?
    else
      true
    end
  end

  def valid_gitlab_event?
    return false unless @record.payload[:scm] == 'gitlab'
    return false unless ALLOWED_GITLAB_EVENTS.include?(@record.payload[:event])

    case @record.payload[:event]
    when 'Merge Request Hook'
      return true if SCMWebhook::ALLOWED_MERGE_REQUEST_ACTIONS.include?(@record.payload[:action])

      @record.errors.add(:base, 'Merge request action not supported.')
    when 'Push Hook', 'Tag Push Hook'
      valid_push_event?
    else
      true
    end
  end

  def valid_push_event?
    return true if @record.payload.fetch(:ref, '').start_with?('refs/heads/', 'refs/tags/')

    @record.errors.add(:base, 'Push event supported only for branches/tags with a valid reference.')
  end
end
