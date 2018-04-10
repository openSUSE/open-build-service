# frozen_string_literal: true
module Cloud
  module Azure
    class Configuration < ApplicationRecord
      # maximum length has to be 245 (2048 bit RSA keys cannot encrypt more than 245 characters)
      validates :application_id, presence: { message: 'ID can\'t be blank' },
        length: { maximum: 245, too_long: 'ID is too long (maximum is 245 characters)' }, on: :update
      validates :application_key, presence: true, length: { maximum: 245 }, on: :update

      before_save :encrypt_credentials

      belongs_to :user

      def self.table_name_prefix
        'cloud_azure_'
      end

      def available?
        application_id && application_key
      end

      private

      def encrypt_credentials
        public_key = OpenSSL::PKey::RSA.new(::Backend::Api::Cloud.public_key)

        self.application_id = Base64.encode64(public_key.public_encrypt(application_id)) if application_id_changed?
        self.application_key = Base64.encode64(public_key.public_encrypt(application_key)) if application_key_changed?
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
