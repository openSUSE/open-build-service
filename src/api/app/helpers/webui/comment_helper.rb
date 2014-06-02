module Webui::CommentHelper

  def save_comment_form
    opts = {action: 'save_comment'}
    opts[:controller] = params[:controller]
    opts[:project] = @project.name if @project
    opts[:package] = @package.to_param if @package
    opts[:id] = @id if @id
    form_tag(opts) do
      yield
    end
  end
end
