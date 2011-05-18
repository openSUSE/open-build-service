class DriverUpdateController < PackageController

  before_filter :require_project
  before_filter :require_package
  before_filter :require_available_architectures, :only => [:create, :edit]
  before_filter :check_images_repo, :only => [:create, :edit]

  def create
    @repositories = []
    @packages = []
    @binary_packages = []
    @architectures = []
  end


  def edit
    # find the 'create_dud_kiwi' service
    services = Service.find :project => @project, :package => @package
    services = Service.new( :project => @project, :package => @package ) unless services
    service = services.data.find( "service[@name='generator_driver_update_disk']" ).first

    if service.blank?
      flash[:warn] = "No Driver update disk section found in _services, creating new"
      redirect_to :action => :create, :project => @project, :package => @package and return
    end

    #parse name, archs, repos from services file
    @repositories = service.find( 'param[@name="instrepo"]' ).map{|repo| {:project => repo.content.split('/')[0], :repo => repo.content.split('/')[1] } }
    @name = service.find( 'param[@name="name"]' ).first.content if service.find( 'param[@name="name"]' ).first
    @distname = service.find( 'param[@name="distname"]' ).first.content if service.find( 'param[@name="distname"]' ).first
    @flavour = service.find( 'param[@name="flavour"]' ).first.content if service.find( 'param[@name="flavour"]' ).first
    @architectures = service.find( 'param[@name="arch"]' ).map{|arch| arch.content} 

    #parse packages, binary packages from dud_packlist.xml file
    packlist = frontend.get_source( :project => @project.to_s, :package => @package.to_s, :filename => "dud_packlist.xml" )
    xml = XML::Document.string(packlist)
    @packages = []
    @binary_packages = {}
    xml.find( "//binarylist" ).each do |binarylist|
      @packages << binarylist['package']
      @binary_packages[binarylist['package']] = []
      binarylist.find( "binary" ).each do |binary|
        @binary_packages[binarylist['package']] << binary['filename']
      end
    end

    render :create
  end


  def save
    valid_http_methods :post

    # TODO: check for valid name, check for minimum 1 architecture

    # write filelist to separate file
    opt = Hash.new
    opt[:project] = @project
    opt[:package] = @package
    opt[:filename] = "dud_packlist.xml"
    opt[:comment] = "Modified via webui"

    fc = FrontendCompat.new
    logger.debug "storing filelist"

    file_content = "<?xml version=\"1.0\"?>\n"
    file_content += "  <packlist>\n"
    file_content += "    <repopackages>\n"

    params[:packages].each do |package|
      file_content += "      <binarylist package=\"" + package + "\">\n"
      params[:binaries].select{|binary| binary =~ /#{package}\//}.each do |binary|
        file_content += "        <binary filename=\"#{binary.gsub(/^.*\//, '')}\"/>\n"
      end
      file_content += "    </binarylist>\n"
    end
    file_content += "    </repopackages>\n"
    file_content += "    <modules/>\n"
    file_content += "    <instsys/>\n"
    file_content += "  </packlist>"

    fc.put_file file_content, opt

    # find the 'generator_driver_update_disk' service
    services = Service.find :project => @project, :package => @package
    services = Service.new( :project => @project, :package => @package ) unless services

    dud_params = []
    dud_params << {:name => 'name', :value => params[:name]}
    dud_params << {:name => 'distname', :value => params[:distname]}
    dud_params |= params[:arch].map{|arch| {:name => 'arch', :value => arch}}
    dud_params |= params[:projects].map{|project| {:name => 'instrepo', :value => project}}

    services.removeService( 'generator_driver_update_disk' )
    services.addService( 'generator_driver_update_disk', -1, dud_params )
    services.save
    Directory.free_cache( :project => @project, :package => @package )

    flash[:success] = "Saved Driver update disk service."
    redirect_to :controller => :package, :action => :show, :project => @project, :package => @package
  end

  #TODO: select architecture of binary packages
  def binaries
    required_parameters :repository
    @repository = params[:repository]
    @buildresult = find_cached(Buildresult, :project => @project, :package => @package,
      :repository => @repository, :view => ['binarylist', 'status'], :expires_in => 1.minute )
    @binaries = @buildresult.data.find('//binary').map{|binary| binary['filename']}
    render :partial => 'binary_packages'
  end


  private

  def require_available_architectures
    begin
      transport = ActiveXML::Config::transport_for(:architecture)
      response = transport.direct_http(URI("/architectures?available=1"), :method => "GET")
      @available_architectures = Collection.new(response)
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "Available architectures not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public", :nextstatus => 404
    end
  end


  def check_images_repo
    unless @project.repositories.include? "images"
      flash.now[:warn] = "You need to add an 'images' repository to your project " +
        "to be able to build a driver update disk image!" 
    end
  end

end
