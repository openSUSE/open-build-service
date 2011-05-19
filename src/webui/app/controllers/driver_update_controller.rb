class DriverUpdateController < PackageController

  before_filter :require_project
  before_filter :require_package
  before_filter :require_available_architectures, :only => [:create, :edit]
  before_filter :check_images_repo, :only => [:create, :edit]

  def create
    services = Service.find :project => @project, :package => @package
    services = Service.new( :project => @project, :package => @package ) unless services
    if services.data.find( "service[@name='generator_driver_update_disk']" ).first
      flash[:warn] = "Existing Driver update disk section found in _services, editing that one"
      redirect_to :action => :edit, :project => @project, :package => @package and return
    end
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
    @repositories = service.find( 'param[@name="instrepo"]' ).map{|repo| repo.content}
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

    @name = params[:name]
    @repositories = params[:projects] || []
    @packages = params[:packages] || []
    @binary_packages = {}
    @packages.each do |package|
      @binary_packages[package] = params[:binaries].select{|binary| 
        binary =~ /#{package}\//}.each{|binary| binary.gsub!(/^.*\//, '') } unless params[:binaries].blank?
    end

    @architectures = params[:arch] || []

    errors = ""
    if params[:arch].blank?
      errors += "Please select at least one architecture. \n"
    end
    if params[:name].blank?
      errors += "Please enter a name. \n"
    end
    if params[:projects].blank?
      errors += "Please select at least one repository. \n"
    end
    if params[:packages].blank?
      errors += "Please select at least one package. \n"
    end
    if params[:binaries].blank?
      errors += "Please select at least one binary package. \n"
    end

    unless errors.blank?
      flash.now[:error] = errors
      require_available_architectures
      render :create and return
    end


    # write filelist to separate file
    opt = Hash.new
    opt[:project] = @project
    opt[:package] = @package
    opt[:filename] = "dud_packlist.xml"
    opt[:comment] = "Modified via driver update disk webui"

    fc = FrontendCompat.new
    file_content = "<?xml version=\"1.0\"?>\n"
    file_content += "  <packlist>\n"
    file_content += "    <repopackages>\n"

    @packages.each do |package|
      file_content += "      <binarylist package=\"" + package + "\">\n"
      @binary_packages[package].each do |binary|
        file_content += "        <binary filename=\"#{binary}\"/>\n"
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
    dud_params << {:name => 'name', :value => @name}
    dud_params << {:name => 'distname', :value => params[:distname]}
    dud_params |= @architectures.map{|arch| {:name => 'arch', :value => arch}}
    dud_params |= @repositories.map{|project| {:name => 'instrepo', :value => project}}

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
