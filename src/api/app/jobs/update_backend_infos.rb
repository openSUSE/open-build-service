class UpdateBackendInfos < CreateJob
  attr_accessor :event
  attr_accessor :checked_pkgs

  def initialize(event)
    super(event)
    self.checked_pkgs = {}
  end

  def update_pkg(pkg)
    return if checked_pkgs.has_key? pkg.id
    return if pkg.project.is_locked?
    pkg.update_backendinfo
    checked_pkgs[pkg.id] = 1
    BackendPackage.where(links_to_id: pkg.id).find_each do |p|
      p = Package.find_by_id p.package_id
      update_pkg(p) if p
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
