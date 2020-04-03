module MetaControllerService
  class MetaXMLValidator
    require_dependency 'opensuse/validator'

    attr_reader :meta, :request_data, :errors

    def initialize(kind, params = {})
      @meta = params[:meta]
      @kind = kind
    end

    def call
      Suse::Validator.validate(@kind, @meta)
      @request_data = Xmlhash.parse(@meta)
    rescue Suse::ValidationError => e
      @errors = e.message
    end

    def errors?
      @errors.present?
    end
  end
end
