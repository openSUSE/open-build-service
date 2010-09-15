require "rexml/document"

class ServiceController < ApplicationController

  def index

    # ACL(index) This is an uninstrumented call. This call is not used in config/routes.
    pass_to_backend 
  end

  def index_service
    
    # ACL(index_service) This is an uninstrumented call.
    pass_to_backend 
  end

end
