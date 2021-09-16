class ScmWebhookEventValidator < ActiveModel::Validator
  ALLOWED_GITHUB_EVENTS = ['pull_request', 'push'].freeze
  ALLOWED_GITLAB_EVENTS = ['Merge Request Hook', 'Push Hook'].freeze

  ALLOWED_PULL_REQUEST_ACTIONS = ['closed', 'opened', 'reopened', 'synchronize'].freeze
  ALLOWED_MERGE_REQUEST_ACTIONS = ['close', 'merge', 'open', 'reopen', 'update'].freeze

  def validate(record)
    @record = record

    return if valid_github_event? || valid_gitlab_event?

    # FIXME: This error message is wrong when the SCM isn't supported. This is an edge case, somebody most probably fiddled with the payload.
    @record.errors.add(:base, 'Event not supported.')
  end

  private

  def valid_github_event?
    return false unless @record.payload[:scm] == 'github'
    return false unless ALLOWED_GITHUB_EVENTS.include?(@record.payload[:event])

    case @record.payload[:event]
    when 'pull_request'
      return true if ALLOWED_PULL_REQUEST_ACTIONS.include?(@record.payload[:action])

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
      return true if ALLOWED_MERGE_REQUEST_ACTIONS.include?(@record.payload[:action])

      @record.errors.add(:base, 'Merge request action not supported.')
    when 'Push Hook'
      valid_push_event?
    else
      true
    end
  end

  def valid_push_event?
    return true if @record.payload.fetch(:ref, '').start_with?('refs/heads/')

    @record.errors.add(:base, 'Push event supported only for branches.')
  end
end
