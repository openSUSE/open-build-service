class PublicController < ApplicationController
  include PublicHelper

  # we need to fall back to _nobody_ (_public_)
  before_filter :extract_user_public
  skip_before_filter :extract_user

  def index
    redirect_to :controller => 'main'
  end

  def check_package_access(project, package, use_source=true)

    # don't use the cache for use_source
    if use_source
      DbPackage.get_by_project_and_name(project, package)
      return
    end

    # generic access checks
    key = "public_package:" + project + ":" + package
    allowed = Rails.cache.fetch(key, :expires_in => 30.minutes) do
      begin
        DbPackage.get_by_project_and_name(project, package, use_source: false)
        true
      rescue Exception
        false
      end
    end

    raise DbPackage::UnknownObjectError, "#{project} / #{package} " unless allowed
  end
  private :check_package_access

  # GET /public/build/:project/:repository/:arch/:package
  def build
    valid_http_methods :get
    required_parameters :project

    # project visible/known ? 
    DbProject.get_by_name(params[:project])

    path = unshift_public(request.path)
    path << "?#{request.query_string}" unless request.query_string.empty?

    pass_to_backend path
  end

  # GET /public/source/:project/_meta
  def project_meta
    valid_http_methods :get

    # project visible/known ? 
    DbProject.get_by_name(params[:project])

    pass_to_backend unshift_public(request.path)
  end

  # GET /public/source/:project
  def project_index
    valid_http_methods :get

    # project visible/known ? 
    DbProject.get_by_name(params[:project])
    
    pass_to_backend unshift_public(request.path)
  end

  # GET /public/source/:project/_config
  # GET /public/source/:project/_pubkey
  def project_file
    valid_http_methods :get

    # project visible/known ? 
    DbProject.get_by_name(params[:project])

    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend path
  end

  # GET /public/source/:project/:package
  def package_index
    valid_http_methods :get

    check_package_access(params[:project], params[:package])

    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend path
  end

  # GET /public/source/:project/:package/_meta
  def package_meta
    valid_http_methods :get

    check_package_access(params[:project], params[:package], false)

    pass_to_backend unshift_public(request.path)
  end

  # GET /public/source/:project/:package/:filename
  def source_file
    valid_http_methods :get
    file = params[:filename]

    check_package_access(params[:project], params[:package])

    path = "/source/#{CGI.escape(params[:project])}/#{CGI.escape(params[:package])}/#{CGI.escape(file)}"

    if request.get?
      path += build_query_from_hash(params, [:rev])
      pass_to_backend path
      return
    end
  end

  # GET /public/lastevents
  def lastevents
    valid_http_methods :get, :post   # OBS 2.3 switched to POST
    
    path = unshift_public(request.path)
    if not request.query_string.blank?
      path += "?#{request.query_string}" 
    elsif not request.env["rack.request.form_vars"].blank?
      path += "?#{request.env["rack.request.form_vars"]}" 
    end
    pass_to_backend path
  end

  # GET /public/distributions
  def distributions
    valid_http_methods :get

    render :text => DistributionController.read_distfile, :content_type => "text/xml"
  end

  # GET /public/binary_packages/:project/:package
  def binary_packages

    check_package_access(params[:project], params[:package], false)
    @pkg = DbPackage.find_by_project_and_name(params[:project], params[:package])

    distfile = ActiveXML::XMLNode.new(DistributionController.read_distfile)
    begin
       binaries = Collection.find :id, :what => 'published/binary', :match => "@project='#{params[:project]}' and @package='#{params[:package]}'"
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
    @pkg.db_project.repositories.includes({:path_elements => {:link => :db_project}}).each do |repo|
      # TODO: this code doesnt handle path elements and layering
      # TODO: walk the path and find the base repos? is that desired?
      dist = d[repo.name]
      if dist
        unless binary_map[repo.name].blank?
          dist_id = dist.method_missing(:id)
          @binary_links[dist_id] ||= {}
          binary = binary_map[repo.name].select {|bin| bin.name == @pkg.name}.first
          if binary and dist.vendor == "openSUSE"
            @binary_links[dist_id][:ymp] = { :url => ymp_url(File.join(@pkg.db_project.name, repo.name, @pkg.name+".ymp") ) }
          end

          @binary_links[dist_id][:binary] ||= []
          binary_map[repo.name].each do |b|
            binary_type = b.method_missing(:type)
            @binary_links[dist_id][:binary] << {:type => binary_type, :arch => b.arch, :url => download_url(b.filepath)}
            if @binary_links[dist_id][:repository].blank?
              repo_filename = (binary_type == 'rpm') ? "#{@pkg.db_project.name}.repo" : ''
              repository_path = File.join(@pkg.db_project.download_name, repo.name, repo_filename)
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

end
