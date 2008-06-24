class PublishedController < ApplicationController
  def binary
    valid_http_methods :get, :post
    if request.post?
      path = request.path + "?" + request.query_string
      forward_data path, :method => :post
    else
      pass_to_source
    end
  end
end
