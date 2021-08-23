class BranchPackage::CheckForUpdate

  attr_accessor :package_hash

  def initialize(package_hash:, update_attribute_namespace:,
                 update_attribute_name:, extend_names:, copy_from_devel:, params:)
    @package_hash = package_hash
    @missing_ok = false
    @update_attribute_namespace = update_attribute_namespace
    @update_attribute_name = update_attribute_name
    @extend_names = extend_names
    @copy_from_devel = copy_from_devel
    @params = params
  end

  def check_for_update_project
    pkg_name, prj = fetch_pkg_and_project(package_hash[:package], package_hash[:link_target_project])
    # Check for defined update project
    update_project = update_project_for_project(prj)
    return if update_project.blank?

    configure_package_link_target_project(pkg_name, update_project)
    # Reset target package name
    # not yet existing target package
    package_hash[:target_package] = package_hash[:package]
    # existing target
    package_hash[:target_package] = package_hash[:package].name if package_hash[:package].is_a?(Package)
    # user specified target name
    package_hash[:target_package] = @params[:target_package] if @params[:target_package]
    # extend parameter given
    package_hash[:target_package] += ".#{package_hash[:link_target_project].name}" if @extend_names
  end

  def missing_ok?
    @missing_ok
  end

  private

  def fetch_pkg_and_project(package, link_target_project)
    pkg = package
    prj = link_target_project

    if pkg.is_a?(Package)
      prj = pkg.project
      pkg_name = pkg.name
    else
      pkg_name = pkg
    end
    [pkg_name, prj]
  end

  def link_target_project_valid?
    package_hash[:link_target_project].is_a?(Project) && package_hash[:link_target_project].find_attribute('OBS', 'BranchTarget')
  end

  def configure_package_link_target_project(pkg_name, update_project)
    package_to_update = update_project.packages.find_by(name: pkg_name)

    if package_to_update
      # We have a package in the update project already, take that
      package_hash[:package] = package_to_update
      package_hash[:link_target_project] = package_to_update.project unless link_target_project_valid?

      if package_hash[:link_target_project].find_package(package_to_update.name) != package_to_update
        # our link target has no project link finding the package.
        # It got found via update project for example, so we need to use it's source
        package_hash[:copy_from_devel] = package_hash[:package]
      end
    else
      package_hash[:link_target_project] = update_project unless link_target_project_valid?
      update_pkg = update_project.find_package(pkg_name, true) # true for check_update_package in older service pack projects

      if update_pkg
        # We have no package in the update project yet, but sources are reachable via project link
        update_pkg_via_devel_project = update_project.develproject.find_package(pkg_name) if update_project.develproject

        if update_pkg_via_devel_project.present?
          # nevertheless, check if update project has a devel project which contains an instance
          package_hash[:package] = update_pkg_via_devel_project
          unless link_target_project_valid?
            package_hash[:link_target_project] = update_pkg_via_devel_project.project unless @copy_from_devel
          end
        end
      else
        # The defined update project can't reach the package instance at all.
        # So we need to create a new package and copy sources
        @missing_ok = true
        package_hash[:copy_from_devel] = package_hash[:package].find_devel_package if package_hash[:package].is_a?(Package)
        package_hash[:package] = pkg_name
      end
    end
  end

  def update_project_for_project(prj)
    updateprj = prj.update_instance(@update_attribute_namespace, @update_attribute_name)
    updateprj == prj ? nil : updateprj
  end
end
