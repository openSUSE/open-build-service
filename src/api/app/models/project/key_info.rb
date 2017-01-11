class Project
  class KeyInfo
    include ActiveModel::Model

    attr_accessor :pubkey, :algorithm, :ssl_certificate

    def self.find_by_project_name(project_name)
      response = Suse::Backend.get(backend_url(project_name)).body
      parsed_response = Xmlhash.parse(response)

      if parsed_response['pubkey'].present?
        key_info_params = {
          pubkey:    parsed_response['pubkey']['_content'],
          algorithm: parsed_response['pubkey']['algo']
        }

        if parsed_response['sslcert'].present?
          key_info_params[:ssl_certificate] = parsed_response['sslcert']
        end

        new(key_info_params)
      end
    end

    def self.backend_url(project_name)
      "/source/#{project_name}/_keyinfo?withsslcert=1"
    end
  end
end
