module Workflows
  class YAMLDownloader
    DOCUMENTATION_LINK = "#{::Workflow::SCM_CI_DOCUMENTATION_URL}#sec.obs.obs_scm_ci_workflow_integration.setup.obs_workflows".freeze
    MAX_FILE_SIZE = 1024 * 1024 # 1MB

    def initialize(scm_payload, token:)
      @scm_payload = scm_payload
      @token = token
    end

    def call
      return download_from_url(@token.workflow_configuration_url) if @token.workflow_configuration_url.present?

      case @scm_payload[:scm]
      when 'gitea'
        download_gitea_yaml_file
      when 'github'
        download_github_yaml_file
      when 'gitlab'
        download_gitlab_yaml_file
      end
    end

    private

    def download_gitea_yaml_file
      url = if @scm_payload[:tag_name].present?
              "#{@scm_payload[:api_endpoint]}/#{@scm_payload[:target_repository_full_name]}/raw/tag/#{@scm_payload[:tag_name]}/#{@token.workflow_configuration_path}"
            else
              "#{@scm_payload[:api_endpoint]}/#{@scm_payload[:target_repository_full_name]}/raw/branch/#{@scm_payload[:target_branch]}/#{@token.workflow_configuration_path}"
            end
      download_from_url(url)
    end

    def download_github_yaml_file
      client = Octokit::Client.new(access_token: @token.scm_token, api_endpoint: @scm_payload[:api_endpoint])
      # :ref can be the name of the commit, branch or tag.
      begin
        content = client.content("#{@scm_payload[:target_repository_full_name]}", path: "/#{@token.workflow_configuration_path}", ref: @scm_payload[:target_branch])[:content]
      rescue Octokit::InvalidRepository => e
        raise Token::Errors::NonExistentRepository, e.message
      rescue Octokit::NotFound => e
        # 'target_branch' can contain a commit sha (when tag push) instead of a branch name
        raise Token::Errors::NonExistentWorkflowsFile,
              "#{@token.workflow_configuration_path} could not be downloaded from the SCM branch/commit #{@scm_payload[:target_branch]}: #{e.message}"
      end
      create_temp_file(Base64.decode64(content))
    end

    # Note: For GitLab we still use the Down gem when workflow_configuration_url is present
    def download_gitlab_yaml_file
      begin
        gitlab_client = Gitlab.client(endpoint: "#{@scm_payload[:api_endpoint]}/api/v4", private_token: @token.scm_token)
        gitlab_file = gitlab_client.file_contents(@scm_payload[:project_id], @token.workflow_configuration_path, @scm_payload[:target_branch])
      rescue Gitlab::Error::NotFound => e
        raise Token::Errors::NonExistentRepository, e.message
      end
      create_temp_file(gitlab_file)
    end

    def create_temp_file(content)
      tempfile = Tempfile.new(["#{Time.zone.now}", '.yaml'])
      tempfile.write(content)
      tempfile.rewind
      tempfile
    end

    def download_from_url(url)
      Down.download(url, max_size: MAX_FILE_SIZE)
    rescue Down::Error => e
      raise Token::Errors::NonExistentWorkflowsFile, "#{@token.workflow_configuration_url} could not be downloaded.\n#{e.message}" if @token.workflow_configuration_url.present?

      # 'target_branch' can contain a commit sha (when tag push) instead of a branch name
      raise Token::Errors::NonExistentWorkflowsFile, "#{@token.workflow_configuration_path} could not be downloaded from the SCM branch/commit #{@scm_payload[:target_branch]}." \
                                                     "\nIs the configuration file in the expected place? Check #{DOCUMENTATION_LINK}\n#{e.message}"
    end
  end
end
