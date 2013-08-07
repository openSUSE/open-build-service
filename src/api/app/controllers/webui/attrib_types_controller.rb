class Webui::AttribTypesController < Webui::BaseController

  def index
    render json: AttribType.includes(:attrib_namespace).all
  end
end
