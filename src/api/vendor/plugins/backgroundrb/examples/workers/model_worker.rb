class ModelWorker < BackgrounDRb::MetaWorker
  set_worker_name :model_worker
  def create(args = nil)
    #add_periodic_timer(2) { add_new_user }
  end

  def add_new_user
    login,age = "Hemant: #{Time.now}",rand(24)
    logger.info "creating user #{login} with age #{age}"
    User.create(:login => login, :age => age)
  end
end

