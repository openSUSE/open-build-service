module MetaControllerService
  class PackageUpdater
    def initialize(project: nil, package: nil, request_data: {}, validator_klass: ::MetaControllerService::PackageMetaValidator)
      @project = project
      @package = package
      @request_data = request_data
      @validator = validator_klass.new(project: project, package: package, request_data: request_data)
      @errors = []
    end

    def call
      @validator.call
      unless @validator.valid?
        @errors = @validator.errors
        return self
      end

      @package.update_from_xml(@request_data)
      self
    rescue Backend::Error, NotFoundError => e
      @errors << "Error while saving the Meta file: #{e}."
      self
    end

    def errors
      @errors.is_a?(Array) ? @errors.to_sentence : @errors
    end

    def valid?
      @validator.valid? && @errors.blank?
    end
  end
end
