class Webui::SubscriptionsController < Webui::BaseController

  def index
    relation = EventSubscription.where(user: User.current)
    if params[:project_id]
      if params[:package_id]
        relation = relation.where(package: Package.get_by_project_and_name(params[:project_id], params[:package_id]))
      else
        relation = relation.where(project: Project.get_by_name(params[:project_id]))
      end
    end

    render json: relation.to_a
  end
end
