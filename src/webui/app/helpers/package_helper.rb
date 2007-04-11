module PackageHelper


  def build_log_url( project, package, platform, arch )
    #get_frontend_url_for( :controller => 'result' ) +
    #  "/#{project}/#{platform}/#{package}/#{arch}/log"
    "https://api.opensuse.org/result/#{project}/#{platform}/#{package}/#{arch}/log"
  end


  def file_url( project, package, filename )
    #get_frontend_url_for( :controller => 'source') +
    #  "/#{project}/#{package}/#{filename}"
    "https://api.opensuse.org/source/#{project}/#{package}/#{filename}"
  end


  def rpm_url( project, package, repository, arch, filename )
    #get_frontend_url_for( :controller => 'rpm' ) +
    #  "/#{project}/#{repository}/#{package}/#{arch}/#{filename}"
    "https://api.opensuse.org/rpm/#{project}/#{repository}/#{package}/#{arch}/#{filename}"
  end

  def human_readable_fsize( bytes )
    logger.debug "### #{bytes} bytes"
    return "NaN" if (bytes.kind_of? String and bytes !~ /^[0-9]+$/)
    n = bytes.to_i

    if n < 10000
      return "#{n} B"
    elsif n < 900000
      return "#{n/2**10} kB"
    else
      return (n/Float(2**20)).to_s.match(/^\d+\.\d{0,2}/)[0] + " MB"
    end
  end

end

