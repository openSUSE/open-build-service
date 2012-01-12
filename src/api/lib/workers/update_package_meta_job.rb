class UpdatePackageMetaJob

  def initialize
  end

  def perform
    DbProject.find(:all).each do |prj|
      prj.db_packages.each do |pkg|
        pkg.set_package_kind
      end
    end
  end

end


