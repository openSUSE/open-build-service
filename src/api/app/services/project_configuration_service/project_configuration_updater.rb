module ProjectConfigurationService
  class ProjectConfigurationUpdater
    def initialize(project, user, params)
      @user = user
      @project = project
      @params = params
    end

    def call
      @config = @project.config.save(sliced_params, @params[:config])
      self
    end

    def saved?
      @config.present? || false
    end

    def errors
      @project.config.errors.full_messages.to_sentence
    end

    private

    def sliced_params
      @params[:user] = @user.login
      sliced_params = @params.slice(:user, :comment)
      sliced_params.permit!
      sliced_params
    end
  end
end
