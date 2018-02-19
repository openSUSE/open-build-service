module Cloud
  module Azure
    class Configuration < ApplicationRecord
      validate :presence_of_fields
      before_save :encrypt_credentials

      belongs_to :user

      def self.table_name_prefix
        'cloud_azure_'
      end

      private

      def encrypt_credentials
        self.application_id = Crypto::Encrypt.cloud_upload_data(application_id) if application_id_changed?
        self.application_key = Crypto::Encrypt.cloud_upload_data(application_key) if application_key_changed?
      end

      # a new record has no application id and application key, so we only validate if the user
      # tries to update these fields.
      def presence_of_fields
        return if application_id && application_key

        errors.add(:application_id, 'ID must not be blank') if application_id.blank?
        errors.add(:application_key, 'must not be blank') if application_key.blank?
      end
    end
  end
end

# == Schema Information
#
# Table name: cloud_azure_configurations
#
#  id              :integer          not null, primary key
#  user_id         :integer          indexed
#  application_id  :text(65535)
#  application_key :text(65535)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_cloud_azure_configurations_on_user_id  (user_id)
#
