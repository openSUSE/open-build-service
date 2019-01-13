module MetaControllerService
  class MetaXMLValidator
    require_dependency 'opensuse/validator'

    attr_reader :meta, :request_data, :errors

    def initialize(params = {})
      @meta = params[:meta]
    end

    def call(xml_type = :project)
      Suse::Validator.validate(xml_type.to_s, @meta)
      @request_data = Xmlhash.parse(@meta)
    rescue Suse::ValidationError => exception
      @errors = exception.message
    end

    def errors?
      @errors.present?
    end
  end
end
