module GiteaAPI
  module V1
    class Client
      HTTP_OK_CODE = 200
      HTTP_CREATED_CODE = 201
      HTTP_BAD_REQUEST_CODE = 400
      HTTP_UNAUTHORIZED_CODE = 401
      HTTP_FORBIDDEN_CODE = 403
      HTTP_NOT_FOUND_CODE = 404

      GiteaApiError = Class.new(StandardError)
      BadRequestError = Class.new(GiteaApiError)
      UnauthorizedError = Class.new(GiteaApiError)
      ForbiddenError = Class.new(GiteaApiError)
      NotFoundError = Class.new(GiteaApiError)
      ConnectionError = Class.new(GiteaApiError)
      ApiError = Class.new(GiteaApiError)

      def initialize(api_endpoint:, token:)
        @api_endpoint = "#{api_endpoint}/api/v1/"
        @token = token
      end

      # owner: owner of the repository
      # repo: name of the repository
      # sha: sha of the commit
      # https://try.gitea.io/api/swagger#/repository/repoCreateStatus
      def create_commit_status(owner:, repo:, sha:, state:, **kwargs)
        begin
          @response = client.post(
            "repos/#{owner}/#{repo}/statuses/#{sha}",
            { state: state, context: kwargs[:context], description: kwargs[:description],
              target_url: kwargs[:target_url] }
          )
        rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
          raise ConnectionError, "Failed to report back to Gitea: #{e.message}"
        end

        return @response.body if request_successful?

        raise error_class, "HTTP Code: #{@response.status}, response: #{@response.body['message']}"
      end

      private

      def client
        @client ||= Faraday.new(@api_endpoint) do |f|
          f.headers['Authorization'] = "token #{@token}"
          f.request(:json)
          f.response(:json) # Faraday decodes response body as JSON
          f.adapter(:net_http)
        end
      end

      def request_successful?
        [HTTP_OK_CODE, HTTP_CREATED_CODE].include?(@response.status)
      end

      def error_class
        case @response.status
        when HTTP_BAD_REQUEST_CODE
          BadRequestError
        when HTTP_UNAUTHORIZED_CODE
          UnauthorizedError
        when HTTP_FORBIDDEN_CODE
          ForbiddenError
        when HTTP_NOT_FOUND_CODE
          NotFoundError
        else
          ApiError
        end
      end
    end
  end
end
