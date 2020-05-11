module MetaControllerService
  class ProjectUpdater
    def initialize(project: nil, request_data: {}, validator_klass: ::MetaControllerService::MetaValidator)
      @project = project
      @request_data = request_data
      @validator = validator_klass.new(project: project, request_data: request_data)
    end

    def call
      @validator.call
      unless @validator.valid?
        @errors = @validator.errors
        return self
      end

      Project.transaction do
        @errors = @project.update_from_xml(@request_data)[:error]
        @project.store if valid?
      end
      self
    end

    def errors
      @errors.is_a?(Array) ? @errors.join("\n") : @errors
    end

    def valid?
      @validator.valid? && @errors.blank?
    end
  end
end
