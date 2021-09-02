module Workflows
  class YAMLDownloader
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
      raise Token::Errors::NonExistentWorkflowsFile, ".obs/workflows.yml could not be downloaded from the SCM branch #{@scm_payload[:target_branch]}: #{e.message}"
    end

    def download_url
      case @scm_payload[:scm]
      when 'github'
        client = Octokit::Client.new(access_token: @token.scm_token, api_endpoint: @scm_payload[:api_endpoint])
        client.content("#{@scm_payload[:target_repository_full_name]}", path: '/.obs/workflows.yml', ref: @scm_payload[:target_branch])[:download_url]
      when 'gitlab'
        "#{@scm_payload[:api_endpoint]}/#{@scm_payload[:path_with_namespace]}/-/raw/#{@scm_payload[:target_branch]}/.obs/workflows.yml"
      end
    rescue Octokit::NotFound => e
      raise Token::Errors::NonExistentWorkflowsFile, ".obs/workflows.yml could not be downloaded from the SCM branch #{@scm_payload[:target_branch]}: #{e.message}"
    end
  end
end
