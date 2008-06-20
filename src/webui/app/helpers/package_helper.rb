module PackageHelper


  def build_log_url( project, package, platform, arch )
    get_frontend_url_for( :controller => 'result' ) +
      "/#{project}/#{platform}/#{package}/#{arch}/log"
  end


  def file_url( project, package, filename )
    get_frontend_url_for( :controller => 'source') +
      "/#{project}/#{package}/#{filename}"
  end


  def rpm_url( project, package, repository, arch, filename )
    get_frontend_url_for( :controller => 'build' ) +
      "/#{project}/#{repository}/#{package}/#{arch}/#{filename}"
  end

  def human_readable_fsize( bytes )
    number_to_human_size(bytes, 2)
  end

end

