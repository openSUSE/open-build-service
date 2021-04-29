class SCMStatusReporter
  attr_accessor :payload, :scm_token, :state

  def initialize(payload, scm_token, event = nil)
    @payload = payload
    @scm_token = scm_token

    # Depending on the SCM, it's different
    #   GitHub: pending, success, failure or error
    #   GitLab: pending, success, failed, running or canceled
    @state = if event.nil?
               'pending'
             else
               case event.class.name
               when 'Event::BuildFail'
                 github? ? 'failure' : 'failed'
               when 'Event::BuildSuccess'
                 'success'
               else
                 'pending'
               end
             end
  end

  def call
    if github?
      github_client = Octokit::Client.new(access_token: @scm_token)
      # https://docs.github.com/en/rest/reference/repos#create-a-commit-status
      github_client.create_status("#{@payload[:repository_owner]}/#{@payload[:repository_name]}",
                                  @payload[:commit_sha],
                                  @state,
                                  { context: 'OBS Workflow' })
    else
      gitlab_client = Gitlab.client(endpoint: 'https://gitlab.com/api/v4',
                                    private_token: @scm_token)
      # https://docs.gitlab.com/ce/api/commits.html#post-the-build-status-to-a-commit
      gitlab_client.update_commit_status(@payload[:project_id],
                                         @payload[:commit_sha],
                                         @state,
                                         { context: 'OBS Workflow' })
    end
  end

  private

  def github?
    @payload[:scm] == :github
  end
end
