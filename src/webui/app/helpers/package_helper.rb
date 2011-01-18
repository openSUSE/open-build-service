module PackageHelper

  protected
  
  def build_log_url( project, package, repository, arch )
    get_frontend_url_for( :controller => 'result' ) +
      "/#{project}/#{repository}/#{package}/#{arch}/log"
  end


  def file_url( project, package, filename, revision=nil )
    # use public/ here to avoid extra login to api in webui
    url = get_frontend_url_for( :controller => '') +
      "public/source/#{project}/#{package}/#{CGI.escape filename}?"
    url += "rev=#{CGI.escape revision}&" if revision
    return url
  end


  def rpm_url( project, package, repository, arch, filename )
    get_frontend_url_for( :controller => 'build' ) +
      "/#{project}/#{repository}/#{arch}/#{package}/#{filename}"
  end

  def human_readable_fsize( bytes )
    number_to_human_size bytes
  end
  
  def guess_code_class( filename )
    case filename
      when "_link" then return "xml"
      when "_patchinfo" then return "xml"
      when "_service" then return "xml"
    end
    case Pathname.new(filename).extname.downcase
      when ".changes" then return "changes"
      when ".diff" then return "diff"
      when ".group" then return "xml"
      when ".kiwi" then return "xml"
      when ".patch" then return "diff"
      when ".product" then return "xml"
      when ".rb" then return "ruby"
      when ".spec" then return "spec"
    end
    return "spec"
  end

  include ProjectHelper

  def package_bread_crumb( *args )
    args.insert(0, link_to( @package, :controller => :package, :action => :show, :project => @project, :package => @package ))
    project_bread_crumb( *args )
  end

end

