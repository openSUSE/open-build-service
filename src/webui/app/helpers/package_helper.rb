module PackageHelper
  def build_log_url( project, package, platform, arch )
    "http://#{FRONTEND_HOST}:#{FRONTEND_PORT}/result/#{project}/#{platform}/#{package}/#{arch}/log"
  end

  def file_url( project, package, filename )
    "http://#{FRONTEND_HOST}:#{FRONTEND_PORT}/source/#{project}/#{package}/#{filename}"
  end

  def rpm_url( project, package, repository, arch, filename )
    "http://#{FRONTEND_HOST}:#{FRONTEND_PORT}/rpm/#{project}/#{repository}/#{package}/#{arch}/#{filename}"
  end
end
