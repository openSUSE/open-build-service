module PackageControllerService
  class RebuildTrigger
    def initialize(options = {})
      @package = options[:package]
      @project = options[:project]
      @params = options[:params]
    end

    def rebuild?
      @package.rebuild(@params.slice(*allowed_params).permit!.to_h)
    end

    # When we're in a linked project, the package's project points to some other
    # project, not the one we're triggering the build from.
    # Here we detect that, and if so, we authorize against the linked project.
    def policy_object
      return @project if @project != @package.project

      @package
    end

    def success_message
      "Triggered rebuild for #{@project.name}/#{@package.name} successfully."
    end

    def error_message
      "Error while triggering rebuild for #{@project.name}/#{@package.name}: #{@package.errors.full_messages.to_sentence}."
    end

    private

    def allowed_params
      [:project, :package, :repository, :arch]
    end
  end
end
