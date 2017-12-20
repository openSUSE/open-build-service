module Cloud
  module Ec2
    class Configuration < ApplicationRecord
      has_secure_token :external_id
      belongs_to :user, required: true

      validates :external_id, :arn, uniqueness: true
      # http://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html
      validates :arn, format: { with: /\Aarn:([\w\-\/:])+\z/, message: 'not a valid format', allow_blank: true }

      def self.table_name_prefix
        'cloud_ec2_'
      end
    end
  end
end

# == Schema Information
#
# Table name: cloud_ec2_configurations
#
#  id          :integer          not null, primary key
#  user_id     :integer          indexed
#  external_id :string(255)      indexed => [arn]
#  arn         :string(255)      indexed => [external_id]
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_cloud_ec2_configurations_on_external_id_and_arn  (external_id,arn) UNIQUE
#  index_cloud_ec2_configurations_on_user_id              (user_id)
#
