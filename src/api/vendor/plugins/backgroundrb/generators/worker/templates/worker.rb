class <%= class_name %>Worker < BackgrounDRb::MetaWorker
  set_worker_name :<%= file_name %>_worker
  def create(args = nil)
    # this method is called, when worker is loaded for the first time
  end
end

