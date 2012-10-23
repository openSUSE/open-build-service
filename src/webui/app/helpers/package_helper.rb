module PackageHelper

  protected
  
  def build_log_url( project, package, repository, arch )
    get_frontend_url_for( :controller => 'result' ) +
      "/#{project}/#{repository}/#{package}/#{arch}/log"
  end


  def file_url( project, package, filename, revision=nil )
    url = get_frontend_url_for( :controller => '') +
      "source/#{project}/#{package}/#{CGI.escape filename}?"
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
    return 'xml' if ['_aggregate', '_link', '_patchinfo', '_service'].include?(filename) || filename.match(/.*\.service/)
    return "bash" if filename.match(/^rc[\w-]+$/) # rc-scripts are shell
    return "python" if filename.match(/^.*rpmlintrc$/)
    return "makefile" if filename == "debian.rules"
    return "spec" if filename.match(/^macros\.\w+/)
    ext = Pathname.new(filename).extname.downcase
    case ext
      when ".group" then return "xml"
      when ".kiwi" then return "xml"
      when ".patch", ".dif" then return "diff"
      when ".pl", ".pm" then return "perl"
      when ".product" then return "xml"
      when ".py" then return "python"
      when ".rb" then return "ruby"
      when ".tex" then return "latex"
      when ".js" then return "javascript"
    end
    return ext[1..-1]
  end

  include ProjectHelper

  def package_bread_crumb( *args )
    args.insert(0, link_to_if(params['action'] != 'show', @package, :controller => :package, :action => :show, :project => @project, :package => @package ))
    args.insert(0, link_to( 'Packages', :controller => :project, :action => :packages, :project => @project ))
    project_bread_crumb( *args )
  end

  def nbsp(text)
    return text.gsub(' ', "&nbsp;")
  end

end

