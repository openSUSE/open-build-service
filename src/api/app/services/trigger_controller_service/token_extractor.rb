module TriggerControllerService
  class TokenExtractor
    def initialize(http_request)
      @http_request = http_request
      @token_id = http_request.params[:id]
      @body = @http_request.body.read
    end

    def call
      token = if @token_id
                extract_token_from_request_signature
              else
                extract_auth_token_from_headers
              end

      # We need to store in memory the package in order to do authorization
      token.package_from_association_or_params = token.package || Package.get_by_project_and_name(@http_request.params[:project], @http_request.params[:package],
                                                                                                  token.package_find_options)
      raise ActiveRecord::RecordNotFound if token.package_from_association_or_params.nil? # This can happen due to the Package.get_by_project_and_name method

      token
    end

    private

    def extract_auth_token_from_headers
      auth_token = @http_request.env['HTTP_X_GITLAB_TOKEN'] ||
                   @http_request.env['HTTP_AUTHORIZATION'].to_s.slice(6..-1)
      return unless auth_token

      Token.token_type(@http_request['action']).find_by_string!(auth_token) if auth_token.match?(%r{^[A-Za-z0-9+/]+$})
    end

    def extract_token_from_request_signature
      token = Token::Service.find_by(id: @token_id)
      return token if token && token.valid_signature?(signature, @body)
    end

    # from Token::Service
    def valid_signature?(signature)
      return false unless signature

      ActiveSupport::SecurityUtils.secure_compare(signature_of(@body), signature)
    end

    # from Token::Service
    def signature_of
      # TODO: use sha256 (from X-Hub-Signature-256)
      'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), string, @body)
    end

    # To trigger the webhook, the sender needs to
    # generate a signature with a secret token.
    # The signature needs to be generated over the
    # payload of the HTTP request and stored
    # in a HTTP header.
    # GitHub: HTTP_X_HUB_SIGNATURE
    # https://developer.github.com/webhooks/securing/
    # Pagure: HTTP_X-Pagure-Signature-256
    # https://docs.pagure.org/pagure/usage/using_webhooks.html
    # Custom signature: HTTP_X_OBS_SIGNATURE
    def signature
      @http_request.env['HTTP_X_OBS_SIGNATURE'] ||
        @http_request.env['HTTP_X_HUB_SIGNATURE'] ||
        @http_request.env['HTTP_X-Pagure-Signature-256']
    end
  end
end
