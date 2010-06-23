class DriverUpdateController < PackageController

  before_filter :require_project
  before_filter :require_package


  def create
    @repositories = @project.each_repository.map{|repo| {:project => @project.name,
        :repo => repo.name, :archs => repo.each_arch.map{|arch| arch.to_s} } }
    @packages = find_cached(Package, :all, :project => @project.name, :expires_in => 30.seconds ).
      each_entry.map{|package| {:name => package.name, :type => 'repopackage'}}[0..50]
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

    @repositories = service.find( 'param[@name="instrepo"]' ).map{|repo| {:project => repo.content.split('/')[0], :repo => repo.content.split('/')[1] } }
    @packages = []
    @packages |= service.find( 'param[@name="repopackage"]' ).map{|package| {:name => package.content, :type => 'repopackage'} }
    @packages |=  service.find( 'param[@name="instsys"]' ).map{|package| {:name => package.content, :type => 'instsys'} }
    @packages |=  service.find( 'param[@name="module"]' ).map{|package| {:name => package.content, :type => 'module'} }
    @name = service.find( 'param[@name="name"]' ).first.content if service.find( 'param[@name="name"]' ).first
    @distname = service.find( 'param[@name="distname"]' ).first.content if service.find( 'param[@name="distname"]' ).first
    @flavour = service.find( 'param[@name="flavour"]' ).first.content if service.find( 'param[@name="flavour"]' ).first

    render :create
  end


  def save
    valid_http_methods :post
    # find the 'generator_driver_update_disk' service
    services = Service.find :project => @project, :package => @package
    services = Service.new( :project => @project, :package => @package ) unless services

    dud_params = []
    dud_params << {:name => 'name', :value => params[:name]}
    dud_params << {:name => 'distname', :value => params[:distname]}
    dud_params << {:name => 'flavour', :value => params[:flavour]}
    dud_params |= params[:projects].map{|project| {:name => 'instrepo', :value => project}}
    dud_params |= params[:packages].map{|package| {:name => 'repopackage', :value => package}}

    services.removeService( 'generator_driver_update_disk' )
    services.addService( 'generator_driver_update_disk', -1, dud_params )
    services.save

    flash[:success] = "Saved Driver update disk service."
    redirect_to :controller => :package, :action => :show, :project => @project, :package => @package
  end

end
