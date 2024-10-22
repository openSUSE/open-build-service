# This component renders a timeline of comments and request activity.
#
# It is used in the beta view of the request show page, under the Overview tab,
# It merges the BsRequestCommentComponent and the BsRequestHistoryElement to
# provide a merged timeline of events.
class BsRequestActivityTimelineComponent < ApplicationComponent
  attr_reader :bs_request, :creator, :timeline, :request_reviews_for_non_staging_projects

  def initialize(bs_request:, history_elements:, request_reviews_for_non_staging_projects: [])
    super
    @bs_request = bs_request
    @creator = User.find_by_login(bs_request.creator) || User.nobody
    action_comments = Comment.on_actions_for_request(@bs_request).without_parent.includes(:user)
    @commented_actions = action_comments.map(&:commentable).uniq.compact

    # IDEA: Forge the first item to remove the need of having the hand-crafted "created request" haml fragment
    @timeline = (
      action_comments +
      @bs_request.comments.without_parent.includes(:user) +
      history_elements
    ).compact.sort_by(&:created_at)
    @request_reviews_for_non_staging_projects = request_reviews_for_non_staging_projects
  end

  def diff_for_ref(comment)
    return unless comment.diff_file_index

    sourcediff = @commented_actions.find(comment.commentable.id).first.webui_sourcediff(rev: comment.source_rev, orev: comment.target_rev).first
    filename = sourcediff.dig('filenames', comment.diff_file_index)
    sourcediff.dig('files', filename)
  end
end
