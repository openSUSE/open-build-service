module PackageControllerService
  class RebuildTrigger
    def initialize(options = {})
      @package_object = options[:package_object]
      @package_name_with_multibuild_suffix = options[:package_name_with_multibuild_suffix]
      @project = options[:project]
      @repository = options[:repository]
      @arch = options[:arch]
    end

    def rebuild?
      @package_object.rebuild(package: @package_name_with_multibuild_suffix, project: @project, repository: @repository, arch: @arch)
    end

    # When we're in a linked project, the package's project points to some other
    # project, not the one we're triggering the build from.
    # Here we detect that, and if so, we authorize against the linked project.
    def policy_object
      return @project if @project != @package_object.project

      @package_object
    end

    def success_message
      "Triggered rebuild for #{@project.name}/#{@package_name_with_multibuild_suffix} successfully."
    end

    def error_message
      "Error while triggering rebuild for #{@project.name}/#{@package_name_with_multibuild_suffix}: #{@package_object.errors.full_messages.to_sentence}."
    end
  end
end
