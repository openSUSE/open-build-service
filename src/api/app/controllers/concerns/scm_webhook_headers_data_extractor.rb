module ScmWebhookHeadersDataExtractor
  extend ActiveSupport::Concern

  def set_scm_event
    @gitlab_event = request.env['HTTP_X_GITLAB_EVENT']
    # Gitea contains the Github headers as well, so we have to check that the Gitea ones are
    # not present for Github
    @github_event = request.env['HTTP_X_GITHUB_EVENT'] unless request.env['HTTP_X_GITEA_EVENT']
    @gitea_event = request.env['HTTP_X_GITEA_EVENT']
  end

  def scm_vendor
    if @gitlab_event
      'gitlab'
    elsif @github_event
      'github'
    elsif @gitea_event
      'gitea'
    end
  end

  def hook_event
    @github_event || @gitlab_event || @gitea_event
  end

  def extract_event_uuid
    request.env['HTTP_X_GITHUB_DELIVERY'] || request.env['HTTP_X_GITLAB_EVENT_UUID']
  end

  def extract_webhook_id
    request.env['HTTP_X_GITHUB_HOOK_ID']
  end

  def extract_generic_event_type
    # We only have filters for push, tag_push, and pull_request
    if hook_event == 'Push Hook' || payload.fetch('ref', '').match('refs/heads')
      'push'
    elsif hook_event == 'Tag Push Hook' || payload.fetch('ref', '').match('refs/tag')
      'tag_push'
    elsif hook_event.in?(['pull_request', 'Merge Request Hook'])
      'pull_request'
    end
  end
end
