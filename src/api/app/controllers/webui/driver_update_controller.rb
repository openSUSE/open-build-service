class Webui::DriverUpdateController < Webui::PackageController
  before_action :set_project
  before_action :require_package
  before_action :require_available_architectures, only: [:create, :edit]
  before_action :check_images_repo, only: [:create, :edit]
  before_action :require_login

  def create
    if @package.services.find_first("service[@name='generator_driver_update_disk']")
      flash[:alert] = 'Existing Driver update disk section found in _services, editing that one'
      redirect_to action: :edit, project: @project, package: @package
      return
    end
    @repositories = []
    @packages = []
    @binary_packages = []
    @architectures = []
  end

  def edit
    # find the 'generator_driver_update_disk' service
    dud_service = @package.services.find_first( "service[@name='generator_driver_update_disk']" )
    if dud_service.blank?
      flash[:alert] = 'No Driver update disk section found in _services, creating new'
      redirect_to action: :create, project: @project, package: @package
      return
    end

    # parse name, archs, repos from services file
    @repositories = dud_service.each('param[@name="instrepo"]').map{|repo| repo.text}
    @name = dud_service.find_first('param[@name="name"]').text if dud_service.find_first( 'param[@name="name"]' )
    @distname = dud_service.find_first('param[@name="distname"]').text if dud_service.find_first( 'param[@name="distname"]' )
    @flavour = dud_service.find_first('param[@name="flavour"]').text if dud_service.find_first( 'param[@name="flavour"]' )
    @architectures = dud_service.each('param[@name="arch"]').map{|arch| arch.text}

    # parse packages, binary packages from dud_packlist.xml file
    @packages = []
    @binary_packages = {}
    @package.source_file_to_axml('dud_packlist.xml').each('//binarylist') do |binarylist|
      binary_package = binarylist.value('package')
      @packages << binary_package
      @binary_packages[binary_package] = []
      binarylist.each('binary') do |binary|
        @binary_packages[binary_package] << binary.value('filename')
      end
    end
    render :create
  end

  def save
    @name = params[:name]
    @repositories = params[:projects] || []
    @architectures = params[:arch] || []
    @packages = params[:packages] || []
    @binary_packages = {}
    @packages.each do |package|
      @binary_packages[package] = params[:binaries].select{|binary|
        binary =~ /#{package}\//
      }.each{|binary| binary.gsub!(/^.*\//, '') } unless params[:binaries].blank?
    end

    # Validations
    errors = []
    errors << "Please select at least one architecture." if params[:arch].blank?
    errors << "Please enter a name." if params[:name].blank?
    errors << "Please select at least one repository." if params[:projects].blank?
    errors << "Please select at least one package." if params[:packages].blank?
    errors << "Please select at least one binary package." if params[:binaries].blank?
    unless errors.blank?
      flash.now[:error] = errors.join("\n")
      require_available_architectures
      render :create
      return
    end

    # Save the dud_packlist.xml file
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
    file_content += '  </packlist>'
    @package.save_file(filename: 'dud_packlist.xml', file: file_content, comment: 'Modified via driver update disk webui')

    # Update/create the 'generator_driver_update_disk' service
    dud_params = [{name: 'name', value: @name}, {name: 'distname', value: params[:distname]}]
    dud_params |= @architectures.map{|arch| {name: 'arch', value: arch}}
    dud_params |= @repositories.map{|project| {name: 'instrepo', value: project}}
    services = @package.services
    services.removeService('generator_driver_update_disk')
    services.addService('generator_driver_update_disk', dud_params)
    unless services.save
      flash.now[:error] = 'Error saving services file'
      render :create
      return
    end

    flash[:success] = 'Saved Driver update disk service.'
    redirect_to controller: :package, action: :show, project: @project, package: @package
  end

  # TODO: select architecture of binary packages
  def binaries
    required_parameters :repository
    @binaries = @package.build_result(params[:repository], ['binarylist', 'status']).each('//binary').map{|binary| binary['filename']}
    render partial: 'binary_packages'
  end

  private

  def check_images_repo
    unless @project.repositories.find_by(name: 'images')
      flash.now[:alert] = "You need to add an 'images' repository to your project " +
          'to be able to build a driver update disk image!'
    end
  end
end
