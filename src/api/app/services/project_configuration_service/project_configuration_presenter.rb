module ProjectConfigurationService
  class ProjectConfigurationPresenter
    attr_reader :config

    def initialize(project, params)
      @project = project
      @params = params
    end

    def call
      @config = @project.config.content(sliced_params.to_h)
      self
    end

    def valid?
      !@config.nil?
    end

    def errors
      @project.config.errors.full_messages.to_sentence
    end

    private

    def sliced_params
      @params.slice(:rev).permit!
    end
  end
end
