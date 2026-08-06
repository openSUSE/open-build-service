class ReconcileLinkedPackageJob < ApplicationJob
  queue_as :default

  def perform(action:, project_name:, package_name:)
    User.session ||= User.default_admin

    project = Project.find_by(name: project_name)
    return if project.nil? || !project.maintained_by_backend?

    package_name = Package.striping_multibuild_suffix(package_name)

    if action.to_s == 'delete'
      destroy_linked_package(project, package_name)
    else
      upsert_linked_package(project, package_name)
    end
  end

  private

  def upsert_linked_package(project, package_name)
    meta = Backend::Api::Sources::Package.meta(project.name, package_name)
  rescue Backend::NotFoundError
    destroy_linked_package(project, package_name)
  else
    package = project.linked_packages.find_or_initialize_by(name: package_name)
    package.assign_attributes_from_from_xml(Xmlhash.parse(meta))
    package.commit_opts = { no_backend_write: 1 }
    package.save!
  end

  def destroy_linked_package(project, package_name)
    package = project.linked_packages.find_by(name: package_name)
    return if package.nil?

    package.commit_opts = { no_backend_write: 1 }
    package.destroy
  end
end
