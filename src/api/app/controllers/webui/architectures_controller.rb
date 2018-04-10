# frozen_string_literal: true
# Enabling/Disabling default architectures
class Webui::ArchitecturesController < Webui::WebuiController
  before_action :require_admin

  def index
    @architectures = Architecture.order(:name)
  end

  def bulk_update_availability
    all_valid = true
    params[:archs].each do |name, value|
      arch = Architecture.find_by(name: name)
      arch.available = value
      all_valid &&= arch.save
    end

    ::Configuration.write_to_backend

    respond_to do |format|
      if all_valid
        format.html { redirect_to architectures_path, notice: 'Architectures successfully updated.' }
      else
        format.html { redirect_back(fallback_location: root_path, error: 'Not all architectures could be saved') }
      end
    end
  end
end
