module Cloud
  module Ec2
    class Configuration < ApplicationRecord
      REGIONS = [
        ['US East (N. Virginia)', 'us-east-1'],
        ['US East (Ohio)', 'us-east-2'],
        ['US West (N. California)', 'us-west-1'],
        ['US West (Oregon)', 'us-west-2'],
        ['Canada (Central)', 'ca-central-1'],
        ['EU (Frankfurt)', 'eu-central-1'],
        ['EU (Ireland)', 'eu-west-1'],
        ['EU (London)', 'eu-west-2'],
        ['EU (Paris)', 'eu-west-3'],
        ['Asia Pacific (Tokyo)', 'ap-northeast-1'],
        ['Asia Pacific (Seoul)', 'ap-northeast-2'],
        ['Asia Pacific (Singapore)', 'ap-southeast-1'],
        ['Asia Pacific (Sydney)', 'ap-southeast-2'],
        ['Asia Pacific (Mumbai)', 'ap-south-1'],
        ['South America (São Paulo)', 'sa-east-1']
      ].freeze

      has_secure_token :external_id
      belongs_to :user, required: true

      validates :external_id, uniqueness: true
      validates :arn, uniqueness: true, allow_nil: true
      # http://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html
      validates :arn, format: { with: /\Aarn:([\w\/:* +=,\.@\-_])+\z/, message: 'not a valid format', allow_blank: true }

      def self.table_name_prefix
        'cloud_ec2_'
      end

      def upload_parameters
        attributes.except('id', 'created_at', 'updated_at')
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
