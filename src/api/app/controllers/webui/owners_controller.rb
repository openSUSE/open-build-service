include SearchHelper

class Webui::OwnersController < Webui::BaseController

  def index
    required_parameters :binary

    Suse::Backend.start_test_backend if Rails.env.test?

    @owners = search_owner(params, params[:binary])
  end

end
