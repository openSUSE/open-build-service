module Crypto
  module Encrypt
    def self.cloud_upload_data(data)
      crypto = GPGME::Crypto.new(armor: true)
      crypto.encrypt(data, recipients: PublicKeys.cloud_upload.fingerprint, always_trust: true).to_s
    end
  end

  module PublicKeys
    def self.cloud_upload
      import_cloud_upload_key
      raise 'could not find public key for cloud upload' unless Thread.current[:cloud_upload_key]
      Thread.current[:cloud_upload_key]
    end

    def self.find_by_fingerprint(fingerprint)
      # remove white spaces to make it comparable
      fingerprint.gsub!(/\s+/, '')

      # only operate on the first element as fingerprints are always unique and there
      # cannot be more than one item in the array
      key = GPGME::Key.find(fingerprint).first
      return key if key && key.fingerprint.casecmp(fingerprint.downcase).zero?
    end

    def self.import_cloud_upload_key
      return if Thread.current[:cloud_upload_key]

      public_key = Nokogiri::XML(Backend::Api::Cloud.public_key(view: :info))
      GPGME::Key.import(public_key.children.first.children.to_s)
      Thread.current[:cloud_upload_key] = find_by_fingerprint(public_key.children.first.attributes['fingerprint'].to_s)
    end
  end
end
