class ScmWebhookEventValidator < ActiveModel::Validator
  ALLOWED_GITHUB_EVENTS = ['pull_request'].freeze
  ALLOWED_GITLAB_EVENTS = ['Merge Request Hook'].freeze

  ALLOWED_PULL_REQUEST_ACTIONS = ['opened', 'synchronize'].freeze
  ALLOWED_MERGE_REQUEST_ACTIONS = ['open', 'update'].freeze

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
    else
      true
    end
  end
end
