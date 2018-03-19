require 'builder'

module Cloud
  module Params
    class Ec2
      include ActiveModel::Validations
      include ActiveModel::Model

      attr_accessor :region, :ami_name
      validates :region, presence: true, inclusion: {
        in: ::Cloud::Ec2::Configuration::REGIONS.map(&:second), message: "'%{value}' is not a valid EC2 region"
      }
      validates :ami_name, presence: true, length: { maximum: 100 }
      validate :valid_ami_name

      def self.build(params)
        new(params.slice(:region, :ami_name))
      end

      def to_xml(options = {})
        builder = options[:builder] || Builder::XmlMarkup.new(options)
        builder.cloud_upload_params do |xml|
          xml.ami_name ami_name
          xml.region region
        end
      end

      private

      def valid_ami_name
        return if Project.valid_name?(ami_name)
        errors.add(:ami_name, "'#{ami_name}' is not a valid ami name (only letters, numbers, dots and hyphens)")
      end
    end
  end
end
