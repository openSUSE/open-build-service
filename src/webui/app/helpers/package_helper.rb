module PackageHelper
  # TODO: change hardcoded url to some config variable, don't use FRONTEND_HOST
  #       because it is used for the internal connection bypassing ichain
  #       and is not accessible from outside
  def build_log_url( project, package, platform, arch )
    "http://api.opensuse.org/result/#{project}/#{platform}/#{package}/#{arch}/log"
  end

  def file_url( project, package, filename )
    "https://api.opensuse.org/source/#{project}/#{package}/#{filename}"
  end

  def rpm_url( project, package, repository, arch, filename )
    "http://api.opensuse.org/rpm/#{project}/#{repository}/#{package}/#{arch}/#{filename}"
  end
end
