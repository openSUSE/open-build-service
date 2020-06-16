module MetaControllerService
  class MetaXMLValidator
    attr_reader :meta, :request_data, :errors

    def initialize(params = {})
      @meta = params[:meta]
    end

    def call
      Suse::Validator.validate('project', @meta)
      @request_data = Xmlhash.parse(@meta)
    rescue Suse::ValidationError => e
      @errors = e.message
    end

    def errors?
      @errors.present?
    end
  end
end
