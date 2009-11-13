class XmppWorker < BackgrounDRb::MetaWorker
  set_worker_name :xmpp_worker
  def create(args = nil)
    # this method is called, when worker is loaded for the first time
  end
end

