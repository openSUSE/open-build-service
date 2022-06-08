module Workflows
  class YAMLDownloader
    DOCUMENTATION_LINK = "#{::Workflow::SCM_CI_DOCUMENTATION_URL}#sec.obs.obs_scm_ci_workflow_integration.setup.obs_workflows".freeze
    MAX_FILE_SIZE = 1024 * 1024 # 1MB

    def initialize(scm_payload, token:)
      @scm_payload = scm_payload
      @token = token
    end

    def call
      download_yaml_file
    end

    private

    def download_yaml_file
      Down.download(download_url, max_size: MAX_FILE_SIZE)
    rescue Down::Error => e
      # 'target_branch' can contain a commit sha (when tag push) instead of a branch name
      raise Token::Errors::NonExistentWorkflowsFile, ".obs/workflows.yml could not be downloaded from the SCM branch/commit #{@scm_payload[:target_branch]}." \
                                                     "\nIs the configuration file in the expected place? Check #{DOCUMENTATION_LINK}\n#{e.message}"
    end

    def download_url
      case @scm_payload[:scm]
      when 'github'
        client = Octokit::Client.new(access_token: @token.scm_token, api_endpoint: @scm_payload[:api_endpoint])
        # :ref can be the name of the commit, branch or tag.
        client.content("#{@scm_payload[:target_repository_full_name]}", path: '/.obs/workflows.yml', ref: @scm_payload[:target_branch])[:download_url]
      when 'gitlab'
        # This GitLab URL admits both a branch name and a commit sha.
        "#{@scm_payload[:api_endpoint]}/#{@scm_payload[:path_with_namespace]}/-/raw/#{@scm_payload[:target_branch]}/.obs/workflows.yml"
      end
    rescue Octokit::InvalidRepository => e
      raise Token::Errors::NonExistentRepository, e.message
    rescue Octokit::NotFound => e
      # 'target_branch' can contain a commit sha (when tag push) instead of a branch name
      raise Token::Errors::NonExistentWorkflowsFile, ".obs/workflows.yml could not be downloaded from the SCM branch/commit #{@scm_payload[:target_branch]}: #{e.message}"
    end
  end
end
