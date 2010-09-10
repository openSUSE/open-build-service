class PublishedController < ApplicationController
  def binary
    valid_http_methods :get, :post

    # ACL(binary) TODO: this is an uninstrumented call
    pass_to_backend
  end
end
