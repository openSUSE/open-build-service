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
end
