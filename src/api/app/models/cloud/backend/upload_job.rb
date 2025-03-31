require 'ostruct' # for OpenStruct

module Cloud
  module Backend
    class UploadJob
      include ActiveModel::Model
      include ActiveModel::Validations
      extend Forwardable

      attr_accessor :xml, :exception
      attr_writer :xml_object

      def_delegators :xml_object,
                     :name,
                     :state,
                     :details,
                     :target,
                     :user,
                     :project,
                     :package,
                     :repository,
                     :arch,
                     :filename,
                     :size
      alias id name
      alias architecture arch
      validate :validate_xml

      def self.create(params)
        xml = ::Backend::Api::Cloud.upload(params)

        new(xml: xml)
      rescue ::Backend::Error, Timeout::Error => e
        new(exception: e.message)
      end

      def self.find(job_id, options = {})
        xml = ::Backend::Api::Cloud.upload_jobs([job_id])
        return xml if options[:format] == :xml

        xml_hash = Xmlhash.parse(xml)['clouduploadjob']
        return if xml_hash.blank?

        new(xml_object: OpenStruct.new(xml_hash))
      rescue Backend::Error, Timeout::Error
        nil
      end

      def self.all(user, options = {})
        xml = ::Backend::Api::Cloud.upload_jobs(user.upload_jobs.pluck(:job_id))
        return xml if options[:format] == :xml

        [Xmlhash.parse(xml)['clouduploadjob']].flatten.compact.map! do |xml_hash|
          new(xml_object: OpenStruct.new(xml_hash))
        end
      rescue Backend::Error, Timeout::Error
        []
      end

      def created
        Time.at(xml_object.created.to_i)
      end
      alias created_at created

      private

      def xml_object
        @xml_object ||= OpenStruct.new(xml_hash)
      end

      def xml_hash
        @xml_hash ||= Xmlhash.parse(xml) if xml
      end

      def validate_xml
        return if exception.blank?

        message = Xmlhash.parse(exception).try(:fetch, 'summary', nil) || exception
        errors.add(:base, message)
      end
    end
  end
end
