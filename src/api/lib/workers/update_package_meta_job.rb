class UpdatePackageMetaJob

  def initialize
  end

  def perform
    Project.find(:all).each do |prj|
      next unless Project.exists?(prj)
      prj.packages.each do |pkg|
        next unless Package.exists?(pkg)
        begin
          pkg.set_package_kind
        rescue ActiveXML::Transport::Error
        end
      end
    end
  end

end


