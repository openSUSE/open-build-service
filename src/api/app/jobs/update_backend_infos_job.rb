class UpdateBackendInfosJob < CreateJob
  def perform(event_id)
    event = Event::Base.find(event_id)
    payload = event.payload
    package = Package.find_by_project_and_name(payload['project'], payload['package'])
    return unless package # there is nothing we can do

    @checked_pkgs = {}
    update_package(package)
  end

  private

  def update_package(package)
    return if @checked_pkgs.key?(package.id)
    return if package.project.locked?

    package.update_backendinfo
    @checked_pkgs[package.id] = 1
    BackendPackage.where(links_to_id: package.id).find_each do |linked_package|
      linked_package = Package.find_by_id(linked_package.package_id)
      update_package(linked_package) if linked_package # dig into recursion
    end
  end
end
