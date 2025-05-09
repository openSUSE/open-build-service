class Webui::LabelsController < Webui::WebuiController
  before_action :set_project
  before_action :set_labelable

  def update
    authorize @labelable, policy_class: LabelPolicy

    if @labelable.update(labels_params)
      flash[:success] = 'Labels updated successfully!'
    else
      flash[:error] = @labelable.errors.full_messages.to_sentence
    end

    redirect_back_or_to root_path
  end

  private

  def labels_params
    params.with_defaults(labels: { labels_attributes: [] }).require(:labels).permit(labels_attributes: [%i[id label_template_id _destroy]])
  end

  def set_labelable
    case params[:labelable_type]
    when 'Package'
      @labelable = Package.find(params[:labelable_id])
    when 'BsRequest'
      @labelable = BsRequest.find(params[:labelable_id])
    end
  end

  def set_project
    @project = Project.find_by_name(params[:project])
  end
end
