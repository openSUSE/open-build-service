class PublishedController < ApplicationController
  def binary
    valid_http_methods :get, :post
    pass_to_backend
  end
end
