class Webui::AttributeController < Webui::WebuiController
  helper :all
  before_action :set_project, only: %i[index new edit]
  before_action :set_package, only: %i[index new edit]
  before_action :set_container, only: %i[index new edit]
  before_action :set_attribute, only: %i[update destroy]

  # raise an exception if authorize has not yet been called.
  after_action :verify_authorized, except: :index

  helper 'webui/project'

  def index
    @attributes = @container.attribs.includes(:issues, :values, attrib_type: [:attrib_namespace]).sort_by(&:fullname)
  end

  def new
    @attribute = if @package
                   Attrib.new(package_id: @package.id)
                 else
                   Attrib.new(project_id: @project.id)
                 end

    authorize @attribute, :create?

    @attribute_types = AttribType.includes(:attrib_namespace).all.sort_by(&:fullname)
  end

  def edit
    @attribute = Attrib.find_by_container_and_fullname(@container, params[:attribute])
    raise ActiveRecord::RecordNotFound unless @attribute

    authorize @attribute

    value_count = @attribute.attrib_type.value_count
    values_length = @attribute.values.length
    (value_count - values_length).times { @attribute.values.build(attrib: @attribute) } if value_count && (value_count > values_length)

    @issue_trackers = IssueTracker.order(:name).all if @attribute.attrib_type.issue_list

    @allowed_values = @attribute.attrib_type.allowed_values.map(&:value)
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
                    success: 'Attribute was successfully created.'
      else
        redirect_to index_attribs_path(project: @attribute.project.to_s, package: @attribute.package.to_s),
                    success: 'Attribute was successfully created.'
      end
    else
      redirect_back_or_to root_path, error: "Saving attribute failed: #{@attribute.errors.full_messages.join(', ')}"
    end
  end

  def update
    authorize @attribute

    if @attribute.update(attrib_params)
      redirect_to edit_attribs_path(project: @attribute.project.to_s, package: @attribute.package.to_s, attribute: @attribute.fullname),
                  success: 'Attribute was successfully updated.'
    else
      redirect_back_or_to root_path, error: "Updating attribute failed: #{@attribute.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    authorize @attribute

    @attribute.destroy
    redirect_back_or_to root_path, success: 'Attribute sucessfully deleted!'
  end

  private

  def set_package
    return unless params[:package]

    require_package
  end

  def set_container
    @container = @package || @project
  end

  def set_attribute
    @attribute = Attrib.find(params[:id])
    if @attribute.container.instance_of?(Package)
      @package = @attribute.container
      @project = @package.project
    elsif @attribute.container.instance_of?(Project)
      @project = @attribute.container
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def attrib_params
    params.require(:attrib).permit(:attrib_type_id, :project_id, :package_id,
                                   values_attributes: %i[id value position _destroy],
                                   issues_attributes: %i[id name issue_tracker_id _destroy])
  end
end
