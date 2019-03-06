module Webui2::InterconnectsController
  def webui2_index
    @interconnect = RemoteProject.new
  end
end
