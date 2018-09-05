class Worker::StatusController < ApplicationController
  def index
    send_data(WorkerStatus.hidden.to_xml)
  end
end
