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
      @params.merge(user: @user.login).slice(:user, :comment).permit!
    end
  end
end
