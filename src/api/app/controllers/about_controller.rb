class AboutController < ApplicationController

  validate_action :index => {:method => :get, :response => :about}
  skip_before_action :extract_user

  def index
    @api_revision = CONFIG['version'].to_s
  end
  
end
