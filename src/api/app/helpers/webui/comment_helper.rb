module Webui::CommentHelper
  # This could also be solved with
  # http://apidock.com/rails/ActiveRecord/NestedAttributes/ClassMethods/accepts_nested_attributes_for
  def save_comment_form
    opts = {action: 'create'}
    opts[:controller] = :comments
    opts[:project] = @project.name if @project
    opts[:package] = @package.to_param if @package
    opts[:id] = @id if @id
    form_tag(opts) do
      yield
    end
  end
end
