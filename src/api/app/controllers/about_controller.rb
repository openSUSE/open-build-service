class AboutController < ApplicationController

  def index
    @api_revision = "#{CONFIG['version']}"
  end
  
end
