class CommentHistoryComponent < ApplicationComponent
  include Webui::PaperTrailHelper

  def initialize(comment)
    super

    @comment = comment
  end

  def render?
    policy(@comment).history? && @comment.versions.where(event: 'update').present?
  end
end
