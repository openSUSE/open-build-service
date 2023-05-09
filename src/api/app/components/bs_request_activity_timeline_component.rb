# This component renders a timeline of comments and request activity.
#
# It is used in the beta view of the request show page, under the Overview tab,
# It merges the BsRequestCommentComponent and the BsRequestHistoryElement to
# provide a merged timeline of events.
class BsRequestActivityTimelineComponent < ApplicationComponent
  attr_reader :bs_request, :creator, :timeline, :request_reviews_for_non_staging_projects

  def initialize(bs_request:, request_reviews_for_non_staging_projects: [])
    super
    @bs_request = bs_request
    @creator = User.find_by_login(bs_request.creator) || User.nobody
    action_comments = @bs_request.bs_request_actions.flat_map { |a| a.comments.without_parent.includes(:user) }
    commented_actions = action_comments.map { |c| c.commentable.id }.uniq.compact
    @diffs = commented_actions.flat_map { |a| @bs_request.webui_actions(action_id: a, diffs: true, cacheonly: 1) }

    # IDEA: Forge the first item to remove the need of having the hand-crafted "created request" haml fragment
    @timeline = (
      action_comments +
      @bs_request.comments.without_parent.includes(:user) +
      @bs_request.history_elements.includes(:user)
    ).compact.sort_by(&:created_at)
    @request_reviews_for_non_staging_projects = request_reviews_for_non_staging_projects
  end

  def diff_for_ref(comment)
    return unless (ref = comment.diff_ref&.match(/diff_([0-9]+)/))

    file_index = ref.captures.first
    sourcediff = @diffs.find { |d| d[:id] == comment.commentable.id }[:sourcediff].first
    filename = sourcediff.dig('filenames', file_index.to_i)
    sourcediff.dig('files', filename)
  end
end
