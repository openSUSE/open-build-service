module PackageHelper

  protected
  
  def build_log_url( project, package, repository, arch )
    get_frontend_url_for( :controller => 'result' ) +
      "/#{project}/#{repository}/#{package}/#{arch}/log"
  end


  def file_url( project, package, filename )
    get_frontend_url_for( :controller => '') +
      "public/source/#{project}/#{package}/#{CGI.escape filename}"
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
       when "_service" then return "xml"
       when "_patchinfo" then return "xml"
    end
    case Pathname.new(filename).extname.downcase
       when ".spec" then return "spec"
       when ".diff" then return "diff"
       when ".patch" then return "patch"
       when ".rb" then return "ruby"
       when ".kiwi" then return "xml"
       when ".group" then return "xml"
       when ".product" then return "xml"
    end
    return "spec"
  end

  def package_tab(text, opts)
    opts[:package] = @package.to_s
    opts[:project] = @project.to_s
    if @current_action.to_s == opts[:action].to_s
      link = "<li class='selected'>"
    else
      link = "<li>"
    end
    link + link_to(text, opts) + "</li>"
  end

  include ProjectHelper

  def package_bread_crumb( *args )
    args.insert(0, link_to( @package, :controller => :package, :action => :show, :project => @project, :package => @package ))
    project_bread_crumb( *args )
  end

end

