module PackageService
  class LinkVerifier
    def initialize(package:, content:)
      @package = package
      @content = Xmlhash.parse(content)
    end

    def call
      if @content['missingok']
        check_project_and_package!
      else
        # permission check
        Package.get_by_project_and_name(target_project_name, target_package_name)
      end
    end

    private

    def target_package_name
      @content.value('package') || @package.name
    end

    def target_project_name
      @content.value('project') || @package.project.name
    end

    def check_project_and_package!
      Project.get_by_name(target_project_name) # permission check
      raise NotMissingError, missingok_error_message if package_exist?
    end

    def package_exist?
      Package.exists_by_project_and_name(target_project_name, target_package_name,
                                         follow_project_links: true, allow_remote_packages: true)
    end

    def missingok_error_message
      "Link contains a missingok statement but link target (#{target_project_name}/#{target_package_name}) exists."
    end
  end
end
