class Worker::StatusController < ApplicationController
  def index
    render xml: WorkerStatus.hidden
  end
end
