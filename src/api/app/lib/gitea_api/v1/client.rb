module GiteaAPI
  module V1
    class Client
      HTTP_OK_CODE = 200
      HTTP_CREATED_CODE = 201
      HTTP_BAD_REQUEST_CODE = 400
      HTTP_UNAUTHORIZED_CODE = 401
      HTTP_FORBIDDEN_CODE = 403
      HTTP_NOT_FOUND_CODE = 404
      HTTP_TOO_MANY_REQUESTS_CODE = 429
      HTTP_INTERNAL_SERVER_ERROR_CODE = 500
      HTTP_BAD_GATEWAY_CODE = 502
      HTTP_SERVICE_UNAVAILABLE_CODE = 503
      HTTP_CLIENT_ERROR_CODES = (400..499)
      HTTP_SERVER_ERROR_CODES = (500..599)

      class GiteaApiError < StandardError
      end

      # The three classes below are only intermediate classes to categorize the errors below them, they are never raised
      # themselves. Only leaf classes are raised.
      class ClientError < GiteaApiError
      end

      class ServerError < GiteaApiError
      end

      class ConnectionError < GiteaApiError
      end

      class BadRequestError < ClientError
      end

      class UnauthorizedError < ClientError
      end

      class ForbiddenError < ClientError
      end

      class NotFoundError < ClientError
      end

      class TooManyRequestsError < ClientError
      end

      # Any client error without a dedicated class
      class UnknownClientError < ClientError
      end

      class InternalServerError < ServerError
      end

      class BadGatewayError < ServerError
      end

      class ServiceUnavailableError < ServerError
      end

      # Any server error without a dedicated class
      class UnknownServerError < ServerError
      end

      class ConnectionFailedError < ConnectionError
      end

      class TimeoutError < ConnectionError
      end

      # A failed TLS handshake is a permanent configuration problem, not a transient network
      # glitch, so it stays out of the ConnectionError family.
      class SSLError < GiteaApiError
      end

      ERROR_CLASSES = {
        HTTP_BAD_REQUEST_CODE => BadRequestError,
        HTTP_UNAUTHORIZED_CODE => UnauthorizedError,
        HTTP_FORBIDDEN_CODE => ForbiddenError,
        HTTP_NOT_FOUND_CODE => NotFoundError,
        HTTP_TOO_MANY_REQUESTS_CODE => TooManyRequestsError,
        HTTP_INTERNAL_SERVER_ERROR_CODE => InternalServerError,
        HTTP_BAD_GATEWAY_CODE => BadGatewayError,
        HTTP_SERVICE_UNAVAILABLE_CODE => ServiceUnavailableError
      }.freeze

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
        rescue Faraday::SSLError => e
          raise SSLError, "Failed to report back to Gitea: #{e.message}"
        rescue Faraday::TimeoutError => e
          raise TimeoutError, "Failed to report back to Gitea: #{e.message}"
        rescue Faraday::ConnectionFailed => e
          raise ConnectionFailedError, "Failed to report back to Gitea: #{e.message}"
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
        return ERROR_CLASSES[@response.status] if ERROR_CLASSES.key?(@response.status)
        return UnknownClientError if HTTP_CLIENT_ERROR_CODES.cover?(@response.status)
        return UnknownServerError if HTTP_SERVER_ERROR_CODES.cover?(@response.status)

        GiteaApiError
      end
    end
  end
end
