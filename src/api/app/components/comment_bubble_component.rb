# This component renders a comment bubble
#
# A comment bubble is a visual component made of the comment content, who wrote
# that comment, and when the comment was written.
#
# It is to be used by the BsRequestCommentComponent and in the list of comments
# made by a user in their profile
class CommentBubbleComponent < ApplicationComponent
  include Webui::ReportablesHelper

  attr_reader :comment, :commentable, :diff, :hideusername

  def initialize(comment:, commentable:, diff: nil, hideusername: false)
    super

    @comment = comment
    @commentable = comment.commentable
    @hideusername = hideusername
    @diff = diff
  end

  def range
    line_index = @comment.diff_ref.match(/diff_[0-9]+_n([0-9]+)/).captures.first
    ((line_index.to_i - 4).clamp(0..)..(line_index.to_i - 1))
  end

  def link_to_comment(comment)
    anchor = "comment-#{comment.id}"
    link = case comment.commentable
           when BsRequest
             Rails.application.routes.url_helpers.request_show_path(comment.commentable.number,
                                                                    anchor: anchor)
           when BsRequestAction
             Rails.application.routes.url_helpers.request_show_path(number: commentable.bs_request.number,
                                                                    request_action_id: commentable.id,
                                                                    anchor: 'tab-pane-changes')
           when Package
             Rails.application.routes.url_helpers.package_show_path(package: comment.commentable,
                                                                    project: comment.commentable.project,
                                                                    anchor: anchor)
           when Project
             Rails.application.routes.url_helpers.project_show_path(comment.commentable,
                                                                    anchor: anchor)
           end
    helpers.link_to(link,
                    title: l(comment.created_at.utc),
                    name: "comment-#{comment.id}") do
      render TimeComponent.new(time: comment.created_at)
    end
  end
end
