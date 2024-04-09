# Methods to help identify which SCM and webhook we are dealing with based on the request headers
module ScmWebhookHeadersDataExtractor
  extend ActiveSupport::Concern

  def hook_event
    request.env['HTTP_X_GITEA_EVENT'] || request.env['HTTP_X_GITHUB_EVENT'] || request.env['HTTP_X_GITLAB_EVENT'] || 'unknown'
  end

  def scm_vendor
    return 'gitlab' if request.env['HTTP_X_GITLAB_EVENT']
    return 'gitea' if request.env['HTTP_X_GITEA_EVENT'] # the order here is important as gitea requests include both headers GITEA_EVENT and GITHUB_EVENT
    return 'github' if request.env['HTTP_X_GITHUB_EVENT']

    'unknown'
  end

  def ignored_event?
    case scm_vendor
    when 'github', 'gitea'
      SCMWebhookEventValidator::ALLOWED_GITHUB_AND_GITEA_EVENTS.exclude?(hook_event)
    when 'gitlab'
      SCMWebhookEventValidator::ALLOWED_GITLAB_EVENTS.exclude?(hook_event)
    end
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
