module Webui::Packages::BinariesHelper
  include Webui::WebuiHelper

  def uploadable?(filename, architecture)
    ::Cloud::UploadJob.new(filename: filename, arch: architecture).uploadable?
  end
end
