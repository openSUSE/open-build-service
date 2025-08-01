class CommentHistoryComponent < ApplicationComponent
  include Webui::PaperTrailHelper

  def initialize(comment)
    @comment = comment
  end

  def render?
    policy(@comment).history? && @comment.versions.where(event: 'update').present?
  end
end
