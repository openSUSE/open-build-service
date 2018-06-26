class Webui::AttributeController < Webui::WebuiController
  helper :all
  before_action :set_container, only: [:index, :new, :edit]
  before_action :set_attribute, only: [:update, :destroy]

  # raise an exception if authorize has not yet been called.
  after_action :verify_authorized, except: :index

  helper 'webui/project'

  def index
    @attributes = @container.attribs
  end

  def new
    if @package
      @attribute = Attrib.new(package_id: @package.id)
    else
      @attribute = Attrib.new(project_id: @project.id)
    end
    authorize @attribute, :create?
  end

  def edit
    @attribute = Attrib.find_by_container_and_fullname(@container, params[:attribute])

    authorize @attribute

    return unless @attribute.attrib_type.value_count && (@attribute.attrib_type.value_count > @attribute.values.length)
    (@attribute.attrib_type.value_count - @attribute.values.length).times { @attribute.values.build(attrib: @attribute) }
  end

  def create
    @attribute = Attrib.new(attrib_params)

    authorize @attribute

    # build the default values
    if @attribute.attrib_type.value_count
      @attribute.attrib_type.value_count.times do
        @attribute.values.build(attrib: @attribute)
      end
    end

    if @attribute.save
      if @attribute.values_editable?
        redirect_to edit_attribs_path(project: @attribute.project.to_s, package: @attribute.package.to_s,
                                      attribute: @attribute.fullname),
                    notice: 'Attribute was successfully created.'
      else
        redirect_to index_attribs_path(project: @attribute.project.to_s, package: @attribute.package.to_s),
                    notice: 'Attribute was successfully created.'
      end
    else
      redirect_back(fallback_location: root_path, error: "Saving attribute failed: #{@attribute.errors.full_messages.join(', ')}")
    end
  end

  def update
    authorize @attribute

    if @attribute.update(attrib_params)
      @attribute.write_container_attributes
      redirect_to edit_attribs_path(project: @attribute.project.to_s, package: @attribute.package.to_s, attribute: @attribute.fullname),
                  notice: 'Attribute was successfully updated.'
    else
      redirect_back(fallback_location: root_path, error: "Updating attribute failed: #{@attribute.errors.full_messages.join(', ')}")
    end
  end

  def destroy
    authorize @attribute

    @attribute.destroy
    redirect_back(fallback_location: root_path, notice: 'Attribute sucessfully deleted!')
  end

  private

  def set_container
    begin
      @project = Project.get_by_name(params[:project])
    rescue APIException
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to(controller: 'project') && return
    end
    if params[:package]
      begin
        @package = Package.get_by_project_and_name(params[:project], params[:package], use_source: false)
      rescue APIException
        redirect_to(project_show_path(@project.to_s), error: "Package #{params[:package]} not found") && (return)
      end
      @container = @package
    else
      @container = @project
    end
  end

  def set_attribute
    @attribute = Attrib.find(params[:id])
    if @attribute.container.instance_of? Package
      @package = @attribute.container
      @project = @package.project
    elsif @attribute.container.instance_of? Project
      @project = @attribute.container
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def attrib_params
    params.require(:attrib).permit(:attrib_type_id, :project_id, :package_id,
                                   values_attributes: [:id, :value, :position, :_destroy],
                                   issues_attributes: [:id, :name, :issue_tracker_id, :_destroy])
  end
end
