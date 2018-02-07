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
                     :vpc_subnet_id,
                     :size,
                     :backend_response
      alias_method :id, :name
      alias_method :architecture, :arch
      validate :validate_xml

      def self.create(params)
        xml = ::Backend::Api::Cloud.upload(params)

        new(xml: xml)
      rescue ActiveXML::Transport::Error, Timeout::Error => exception
        new(exception: exception.message)
      end

      def self.all(user)
        xml = ::Backend::Api::Cloud.status(user)
        [Xmlhash.parse(xml)['clouduploadjob']].flatten.compact.map do |xml_hash|
          new(xml_object: OpenStruct.new(xml_hash))
        end
      rescue ActiveXML::Transport::Error, Timeout::Error
        []
      end

      def created
        Time.at(xml_object.created.to_i).to_datetime
      end
      alias_method :created_at, :created

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
