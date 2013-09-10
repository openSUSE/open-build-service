class CheckPackageEvent

  attr_accessor :event
  attr_accessor :checked_pkgs

  def initialize(event)
    self.event = event
    self.checked_pkgs = {}
  end

  def update_pkg(pkg)
    return if self.checked_pkgs.has_key? pkg.id
    pkg.update_backendinfo
    self.checked_pkgs[pkg.id] = 1
    BackendPackage.where(links_to_id: pkg.id).each do |p|
      update_pkg(Package.find(p.package_id))
    end
  end

  def perform
    pl = event.payload
    pkg = Package.find_by_project_and_name(pl['project'], pl['package'])
    return unless pkg # there is nothing we can do
    # dig into recursion
    update_pkg(pkg)
  end
end