module Webui::RepositoryHelper
  def html_id_for_flag(flag_type, repository, architecture)
    # repository and architecture can be nil
    valid_xml_id("flag-#{flag_type}-#{repository}-#{architecture}")
  end
end
