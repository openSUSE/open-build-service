class Project
  class KeyInfo
    include ActiveModel::Model

    attr_accessor :pubkey,
                  :algorithm,
                  :ssl_certificate,
                  :keyid,
                  :keysize,
                  :expires,
                  :fingerprint

    CACHE_EXPIRY_TIME = 5.minutes

    def self.find_by_project(project)
      response = Rails.cache.fetch("key_info_project_#{project.cache_key}", expires_in: CACHE_EXPIRY_TIME) do
        # don't use _with_ssl for now since it will always create a cert in the backend
        Backend::Connection.get(backend_url(project.name)).body
      end
      parsed_response = Xmlhash.parse(response)

      return unless parsed_response['pubkey'].present?

      key_info_params = {
        pubkey:      parsed_response['pubkey']['_content'],
        algorithm:   parsed_response['pubkey']['algo'],
        keyid:       parsed_response['pubkey']['keyid'],
        keysize:     parsed_response['pubkey']['keysize'],
        expires:     parsed_response['pubkey']['expires'],
        fingerprint: parsed_response['pubkey']['fingerprint']
      }

      if parsed_response['sslcert'].present?
        key_info_params[:ssl_certificate] = parsed_response['sslcert']
      end

      new(key_info_params)
    end

    def self.backend_url(project_name)
      "/source/#{project_name}/_keyinfo"
    end

    def self.backend_url_with_ssl(project_name)
      "/source/#{project_name}/_keyinfo?withsslcert=1"
    end
  end
end
