<% if namespaced? -%>
require_dependency "<%= namespaced_file_path %>/application_controller"

<% end -%>
<% module_namespacing do -%>
# TODO: Please overwrite this comment with something explaining the controller target
class <%= controller_class_name %>Controller < ApplicationController
  #### Includes and extends

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :set_<%= singular_table_name %>, only: [:show, :edit, :update, :destroy]
  # Pundit authorization policies control
  after_action :verify_authorized, :except => :index
  after_action :verify_policy_scoped, :only => :index

  #### CRUD actions

  # GET <%= route_url %>
  def index
    @<%= plural_table_name %> = policy_scope(<%= class_name %>)
  end

  # GET <%= route_url %>/1
  def show
    if @<%= singular_table_name %>.present?
      authorize @<%= singular_table_name %>
    else
      skip_authorization
    end
  end

  # GET <%= route_url %>/new
  def new
    @<%= singular_table_name %> = <%= orm_class.build(class_name) %>
    authorize @<%= singular_table_name %>
  end

  # GET <%= route_url %>/1/edit
  def edit
    authorize @<%= singular_table_name %>
  end

  # POST <%= route_url %>
  def create
    @<%= singular_table_name %> = <%= orm_class.build(class_name, "#{singular_table_name}_params") %>
    authorize @<%= singular_table_name %>
    if @<%= orm_instance.save %>
      redirect_to @<%= singular_table_name %>, notice: <%= "'#{human_name} was successfully created.'" %>
    else
      render :new
    end
  end

  # PATCH/PUT <%= route_url %>/1
  def update
    authorize @<%= singular_table_name %>
    if @<%= orm_instance.update("#{singular_table_name}_params") %>
      redirect_to @<%= singular_table_name %>, notice: <%= "'#{human_name} was successfully updated.'" %>
    else
      render :edit
    end
  end

  # DELETE <%= route_url %>/1
  def destroy
    authorize @<%= singular_table_name %>
    @<%= orm_instance.destroy %>
    redirect_to <%= index_helper %>_url, notice: <%= "'#{human_name} was successfully destroyed.'" %>
  end

  #### Non CRUD actions

  #### Non actions methods
  # Use hide_action if they are not private

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_<%= singular_table_name %>
      @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>
    end

    # Only allow a trusted parameter "white list" through.
    def <%= "#{singular_table_name}_params" %>
      <%- if attributes_names.empty? -%>
      params[:<%= singular_table_name %>]
      <%- else -%>
      params.require(:<%= singular_table_name %>).permit(<%= attributes_names.map { |name| ":#{name}" }.join(', ') %>)
      <%- end -%>
    end
end
<% end -%>
