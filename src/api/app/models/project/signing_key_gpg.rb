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

    def initialize(project_name)
      keyinfo = Xmlhash.parse(key_info_for_project(project_name))
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

    def key_info_for_project(project_name)
      Backend::Api::Sources::Project.key_info(project_name)
    rescue Backend::Error
      '<keyinfo/>'
    end
  end
end
