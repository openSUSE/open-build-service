class Webui::CodeOfConductController < Webui::WebuiController
  def index
    @code_of_conduct = ::Configuration.code_of_conduct

    raise ActiveRecord::RecordNotFound, 'Not Found' if @code_of_conduct.blank?
  end
end
