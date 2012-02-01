class UpdatePackageMetaJob

  def initialize
  end

  def perform
    DbProject.find(:all).each do |prj|
      next unless DbProject.exists?(prj)
      prj.db_packages.each do |pkg|
        next unless DbPackage.exists?(pkg)
        pkg.set_package_kind
      end
    end
  end

end


