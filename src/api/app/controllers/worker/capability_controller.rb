class Worker::CapabilityController < ApplicationController
  def show
    pass_to_backend("/worker/#{params[:worker]}")
  end
end
