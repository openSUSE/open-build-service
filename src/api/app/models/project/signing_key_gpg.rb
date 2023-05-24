class Project
  class SigningKeyGPG
    include ActiveModel::Model

    attr_accessor :origin,
                  :id,
                  :user_id,
                  :algorithm,
                  :size,
                  :expires,
                  :fingerprint,
                  :content

    CACHE_EXPIRY_TIME = 5.minutes

    def initialize(project)
      keyinfo = Xmlhash.parse(key_info_for_project(project))
      @origin = keyinfo['project']

      return if keyinfo['pubkey'].blank?

      @id = keyinfo['pubkey']['keyid']
      @user_id = keyinfo['pubkey']['userid']
      @algorithm = keyinfo['pubkey']['algo']
      @size = keyinfo['pubkey']['keysize']
      @expires = keyinfo['pubkey']['expires']
      @fingerprint = keyinfo['pubkey']['fingerprint']
      @content = keyinfo['pubkey']['_content']
    end

    private

    def key_info_for_project(project)
      Rails.cache.fetch("key_info_project_#{project.cache_key_with_version}", expires_in: CACHE_EXPIRY_TIME) do
        Backend::Api::Sources::Project.key_info(project.name)
      rescue Backend::Error
        '<keyinfo/>'
      end
    end
  end
end
