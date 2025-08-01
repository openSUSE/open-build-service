class CommentComponent < ApplicationComponent
  def initialize(comment:, obj_is_user:, builder:)
    super

    @comment = comment
    @obj_is_user = obj_is_user
    @builder = builder
  end

  def user?
    @obj_is_user
  end

  def attributes
    attrs = { who: comment.user.login, when: comment.created_at, id: comment.id }
    if user?
      attrs[comment.commentable.class.name.downcase.to_sym] = comment.commentable.to_param
      attrs[:project] = comment.commentable.project if comment.commentable.is_a?(Package)
    end
    attrs[:parent] = comment.parent_id if comment.parent_id
    attrs
  end

  def body
    return inline_comment_body if comment.commentable.is_a?(BsRequestAction) && comment.diff_file_index

    comment.body.delete("\u0000")
  end

  private

  attr_accessor :comment

  def inline_comment_body
    sourcediff = comment.commentable.bs_request.webui_actions(action_id: comment.commentable, diffs: true, cacheonly: 1).first[:sourcediff].first

    return comment.body if sourcediff[:error]

    target = "#{comment.commentable.target_project}/#{comment.commentable.target_package}"
    filename = sourcediff['filenames'][comment.diff_file_index]

    "Inline comment for target: '#{target}', file: '#{filename}', and line: #{comment.diff_line_number}:\n\n#{comment.body}"
  end
end
