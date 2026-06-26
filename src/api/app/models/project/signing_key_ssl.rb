class Project
  class SigningKeySSL
    include ActiveModel::Model

    attr_accessor :origin,
                  :serial,
                  :issuer,
                  :subject,
                  :algorithm,
                  :size,
                  :begins,
                  :expires,
                  :fingerprint,
                  :id,
                  :content

    CACHE_EXPIRY_TIME = 5.minutes

    def initialize(project_name)
      keyinfo = Xmlhash.parse(key_info_for_project(project_name))
      return if keyinfo['sslcert'].blank?

      @origin = keyinfo['project'] || project_name
      @id = keyinfo['sslcert']['keyid']
      @serial = keyinfo['sslcert']['serial']
      @issuer = keyinfo['sslcert']['issuer']
      @subject = keyinfo['sslcert']['subject']
      @algorithm = keyinfo['sslcert']['algo']
      @size = keyinfo['sslcert']['keysize']
      @begins = keyinfo['sslcert']['begins']
      @expires = keyinfo['sslcert']['expires']
      @fingerprint = keyinfo['sslcert']['fingerprint']
      @content = keyinfo['sslcert']['_content']
    end

    private

    def key_info_for_project(project_name)
      Backend::Api::Sources::Project.key_info(project_name)
    rescue Backend::Error
      '<keyinfo/>'
    end
  end
end
