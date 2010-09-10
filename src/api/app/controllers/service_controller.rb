require "rexml/document"

class ServiceController < ApplicationController

  def index

    # ACL(index) TODO: this is an uninstrumented call
    pass_to_backend 
  end

  def index_service
    
    # ACL(index_service) TODO: this is an uninstrumented call
    pass_to_backend 
  end

end
