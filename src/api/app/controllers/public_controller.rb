class PublicController < ApplicationController
  include PublicHelper
  skip_before_filter :extract_user
  # we need to fall back to _nobody_ (_public_)
  before_filter :extract_user_public

  def index
    redirect_to :controller => 'main'
  end

  # GET /public/build/:prj/:repo/:arch/:pkg
  def build
    valid_http_methods :get
    required_parameters :prj, :pkg, :repo, :arch
    
    prj = DbProject.find_by_name(params[:prj])
    nobody=User.find_by_login "_nobody_"
    # ACL(build): in case of access, project is really hidden, e.g. does not get listed, accessing says project is not existing
    if prj and prj.disabled_for?('access', params[:repo], params[:arch]) and not nobody.can_access?(prj)
      render_error :message => "Unknown project '#{params[:prj]}'",
      :status => 404, :errorcode => "unknown_project"
      return
    end

    # ACL(build): binarydownload denies access to build files
    if prj and prj.disabled_for?('binarydownload', params[:repo], params[:arch]) and not nobody.can_download_binaries?(prj)
      render_error :status => 403, :errorcode => "download_binary_no_permission",
      :message => "No permission to download binaries from project #{params[:prj]}"
      return
    end

    path = unshift_public(request.path)
    path << "?#{request.query_string}" unless request.query_string.empty?

    if params[:view]
      unless %w(names cpio cache binaryversions solvstate).include?(params[:view])
        render_error :status => 400, :errorcode => "missing_parameter",
          :message => "query parameter 'view' has to be either names, cpio or cache"
        return
      end

      if %w{names binaryversions}.include?(params[:view])
        pass_to_backend path
      else
        headers.update(
          'Content-Type' => 'application/x-cpio'
        )
        render_stream(Net::HTTP::Get.new(path))
      end
    else
      pass_to_backend path
    end
  end

  # GET /public/source/:prj/_meta
  def project_meta
    valid_http_methods :get

    prj = DbProject.find_by_name(params[:prj])
    nobody=User.find_by_login "_nobody_"
    # ACL(project_meta): in case of access, project is really hidden and accessing says project is not existing
    if prj and prj.disabled_for?('access', nil, nil) and not nobody.can_access?(prj)
      render_error :message => "Unknown project '#{params[:prj]}'",
      :status => 404, :errorcode => "unknown_project"
      return
    end

    if prj
      render :text => prj.to_axml, :content_type => 'text/xml'
    else
      if prj = DbProject.find_remote_project(params[:prj])
        # project from remote buildservice, get metadata via backend
        pass_to_backend unshift_public(request.path)
      else
        render_error :message => "Unknown project '#{params[:prj]}'",
          :status => 404, :errorcode => "unknown_project"
      end
    end
  end

  # GET /public/source/:prj
  def project_index
    valid_http_methods :get

    prj = DbProject.find_by_name(params[:prj])
    nobody=User.find_by_login "_nobody_"
    # ACL(project_index): in case of access, project is really hidden and accessing says project is not existing
    if prj and prj.disabled_for?('access', nil, nil) and not nobody.can_access?(prj)
      render_error :message => "Unknown project '#{params[:prj]}'",
      :status => 404, :errorcode => "unknown_project"
      return
    end
    # ACL(project_index): if private view is on behave like pkg without any src files
    if prj and prj.enabled_for?('privacy', nil, nil) and not nobody.can_private_view?(prj)
      render :text => '<directory count="0"></directory>', :content_type => "text/xml"
      return
    end

    if prj
      # ACL(projectlist): a project lists only if project is not protected
      path = unshift_public(request.path)
      path += "?#{request.query_string}" unless request.query_string.empty?
      pass_to_backend path
    else
      dir = Project.find :all
      # ACL(projectlist): projects with flag 'access' are not listed
      accessprjs = DbProject.find( :all, :joins => "LEFT OUTER JOIN flags f ON f.db_project_id = db_projects.id", :conditions => [ "f.flag = 'access'", "ISNULL(f.repo)", "ISNULL(f.architecture_id)"] )
      accessprjs.each do |prj|
        dir.delete_element("//entry[@name='#{prj.name}']") if prj.disabled_for?('access', nil, nil) and not nobody.can_access?(prj)
      end
      render :text => dir.dump_xml, :content_type => "text/xml"
    end
  end

  # GET /public/source/:prj/_config
  # GET /public/source/:prj/_pubkey
  def project_file
    valid_http_methods :get

    prj = DbProject.find_by_name(params[:prj])
    nobody=User.find_by_login "_nobody_"
    # ACL(project_config): in case of access, project is really hidden and accessing says project is not existing
    if prj and prj.disabled_for?('access', nil, nil) and not nobody.can_access?(prj)
      render_error :message => "Unknown project '#{params[:prj]}'",
      :status => 404, :errorcode => "unknown_project"
      return
    end

    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend path
  end

  # GET /public/source/:prj/:pkg
  def package_index
    valid_http_methods :get

    prj = DbProject.find_by_name(params[:prj])
    pkg = prj.find_package(params[:pkg]) if prj
    nobody=User.find_by_login "_nobody_"
    # ACL(package_index): in case of access, package is really hidden and shown as non existing to users without access
    if pkg and pkg.disabled_for?('access', nil, nil) and not nobody.can_access?(pkg)
      render_error :status => 404, :errorcode => 'unknown_package',
        :message => "Unknown package #{params[:pkg]} in project #{params[:prj]}"
      return
    end

    # ACL(package_index): source access forbidden ?
    if pkg and pkg.disabled_for?('sourceaccess', nil, nil) and not nobody.can_source_access?(pkg)
      render_error :status => 403, :errorcode => 'source_access_no_permission',
        :message => "Source access to package #{params[:pkg]} in project #{params[:prj]} is forbidden"
      return
    end

    # ACL(package_index): if private view is on behave like pkg without any src files
    if pkg and pkg.enabled_for?('privacy', nil, nil) and not nobody.can_private_view?(pkg)
      render :text => '<directory count="0"></directory>', :content_type => "text/xml"
      return
    end

    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend path
  end

  # GET /public/source/:prj/:pkg/_meta
  def package_meta
    valid_http_methods :get
    if project = DbProject.find_by_name(params[:prj])
      if pkg = project.find_package(params[:pkg])
        nobody=User.find_by_login "_nobody_"
        # ACL(package_meta): in case of access, package is really hidden and shown as non existing to users without access
        if pkg and pkg.disabled_for?('access', nil, nil) and not nobody.can_access?(pkg)
          render_error :status => 404, :errorcode => 'unknown_package',
          :message => "Unknown package #{params[:pkg]} in project #{params[:prj]}"
          return
        end
        render :text => pkg.to_axml, :content_type => 'text/xml'
      else
         # may be a package in a linked remote project
        pass_to_backend unshift_public(request.path)
      end
    else
      # may be a package in remote project
      pass_to_backend unshift_public(request.path)
    end
  end

  # GET /public/source/:prj/:pkg/:file
  def source_file
    valid_http_methods :get
    file = params[:file]

    prj = DbProject.find_by_name(params[:prj])
    pkg = prj.find_package(params[:pkg]) if prj
    nobody=User.find_by_login "_nobody_"
    # ACL(source_file): access behaves like project not existing
    if pkg and pkg.disabled_for?('access', nil, nil) and not nobody.can_access?(pkg)
      render_error :status => 404, :errorcode => 'not_found',
        :message => "The given package #{params[:pkg]} does not exist in project #{params[:prj]}"
      return
    end

    # ACL(package_index): source access forbidden ?
    if pkg and pkg.disabled_for?('sourceaccess', nil, nil) and not nobody.can_source_access?(pkg)
      render_error :status => 403, :errorcode => 'source_access_no_permission',
        :message => "Source access to package #{params[:pkg]} in project #{params[:prj]} is forbidden"
      return
    end

    path = "/source/#{CGI.escape(params[:prj])}/#{CGI.escape(params[:pkg])}/#{CGI.escape(file)}"

    if request.get?
      path += build_query_from_hash(params, [:rev])
      pass_to_backend path
      return
    end
  end

  # GET /public/lastevents
  def lastevents
    valid_http_methods :get
    
    # ACL(lastevents): This API is not protected at all and displays a event id and a sync flag.

    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?

    render_stream(Net::HTTP::Get.new(path))
  end

  # GET /public/distributions
  def distributions
    valid_http_methods :get

    # ACL(distributions): This API is not protected at all, OBS admin should not put in a hidden project into this list.

    render :text => DistributionController.read_distfile, :content_type => "text/xml"
  end

  # GET /public/binary_packages/:prj/:pkg
  def binary_packages

    nobody=User.find_by_login "_nobody_"
    @prj = DbProject.find_by_name(params[:prj])
    @pkg = DbPackage.find_by_project_and_name(params[:prj], params[:pkg])
    # ACL(binary_packages): in case of access, project is really hidden, e.g. does not get listed, accessing says project is not existing
    # FIXME: OBS interconnect stacking is broken here
    if @prj.nil? or @pkg.nil? or @pkg.disabled_for?('access', nil, nil) and not nobody.can_access?(@pkg)
      render_error :message => "Unknown package '#{params[:project]}/#{params[:package]}'",
        :status => 404, :errorcode => "unknown_package"
      return
    end

    # ACL(binary_packages): binarydownload denies access to build files
    if @pkg.disabled_for?('binarydownload', params[:repository], params[:arch]) and not nobody.can_download_binaries?(@pkg)
      render_error :status => 403, :errorcode => "download_binary_no_permission",
        :message => "No permission to download binaries from package #{params[:package]}, project #{params[:project]}"
      return
    end

    distfile = ActiveXML::XMLNode.new(DistributionController.read_distfile)
    begin
       binaries = Collection.find :id, :what => 'published/binary', :match => "@project='#{@pkg.db_project.name}' and @package='#{@pkg.name}'"
    rescue
      render_error :status => 400, :errorcode => 'search_failure', :message => "The search can't get executed."
      return
    end

    binary_map = Hash.new
    binaries.each do |bin|
      repo_string = bin.repository.to_s
      next if bin.arch.to_s == "src"
      binary_map[repo_string] ||= Array.new
      binary_map[repo_string] << bin
    end

    def scan_distfile(distfile)
      h = HashWithIndifferentAccess.new
      distfile.each_distribution do |dist|
        h["#{dist.project.text()}/#{dist.repository.text()}"] = dist
        h["#{dist.project.text()}"] = dist
        h["#{dist.reponame.text()}"] = dist
      end
      return h
    end
    d = scan_distfile(distfile)

    @binary_links = {}
    @prj.repositories.find(:all, :include => {:path_elements => {:link => :db_project}}).each do |repo|
      # TODO: this code doesnt handle path elements and layering
      # TODO: walk the path and find the base repos? is that desired?
      dist = d[repo.name]
      if dist
        unless binary_map[repo.name].blank?
          dist_id = dist.method_missing(:id)
          @binary_links[dist_id] ||= {}
          binary = binary_map[repo.name].select {|bin| bin.name == @pkg.name}.first
          if binary and dist.vendor == "openSUSE"
            @binary_links[dist_id][:ymp] = { :url => ymp_url(File.join(@prj.name, repo.name, @pkg.name+".ymp") ) }
          end

          @binary_links[dist_id][:binary] ||= []
          binary_map[repo.name].each do |binary|
            binary_type = binary.method_missing(:type)
            @binary_links[dist_id][:binary] << {:type => binary_type, :arch => binary.arch, :url => download_url(binary.filepath)}
            if @binary_links[dist_id][:repository].blank?
              repo_filename = (binary_type == 'rpm') ? "#{@prj.name}.repo" : ''
              repository_path = File.join(@prj.download_name, repo.name, repo_filename)
              @binary_links[dist_id][:repository] ||= { :url => download_url(repository_path) }
            end
          end
          #
        end
      end
    end
  end

  private

  # removes /private prefix from path
  def unshift_public(path)
    if path.match %r{/public(.*)}
      return $1
    else
      return path
    end
  end

  def render_stream(backend_request)
    logger.info "streaming #{backend_request.path}"
    render :status => 200, :text => Proc.new {|request,output|
      response = Net::HTTP.start(SOURCE_HOST,SOURCE_PORT) do |http|
        begin
          http.request(backend_request) do |response|
            response.read_body do |chunk|
              output.write chunk
            end
          end
        rescue Timeout::Error
          logger.info "catched TIMEOUT: #{backend_request.path}"
        end
      end
    }
  end
end
