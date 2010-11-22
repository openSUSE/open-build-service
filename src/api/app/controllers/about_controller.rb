class AboutController < ApplicationController

  validate_action :index => {:method => :get, :response => :about}

  def index
    # ACL(index): nothing to change
    @api_revision = "#{CONFIG['version']}"
  end
  
end
