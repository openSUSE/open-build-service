class CommentsController < ApplicationController
  before_action :find_obj, only: %i[index create]

  def index
    comments = @obj.comments.includes(:user)
    comments += Comment.on_actions_for_request(@obj).includes(:user) if @obj.is_a?(BsRequest)
    @comments = comments.sort_by(&:id)
  end

  def create
    source_rev, target_rev = diff_revisions
    comment = @obj.comments.new(body: request.raw_post, user: User.session, parent_id: params[:parent_id],
                                diff_file_index: diff_file_index, diff_line_number: params[:diff_line_number],
                                source_rev: source_rev, target_rev: target_rev)
    authorize comment, :create?
    comment.save!
    render_ok
  end

  def update
    comment = Comment.find(params[:id])
    authorize comment, :update?
    comment.update!(body: request.raw_post)
    render_ok
  end

  def destroy
    comment = Comment.find(params[:id])
    authorize comment, :destroy?
    comment.blank_or_destroy
    render_ok
  end

  def history
    comment = Comment.find(params[:id])
    authorize comment, :history?

    versions = comment.versions

    @header = { comment: comment.id }
    @comments = versions.filter_map(&:reify)
  end

  protected

  def find_obj
    if params[:project]
      if params[:package]
        @obj = Package.get_by_project_and_name(params[:project], params[:package])
        @header = { project: @obj.project.name, package: @obj.name }
      else
        @obj = Project.get_by_name(params[:project])
        @header = { project: @obj.name }
      end
    elsif params[:request_number]
      find_request_or_action
    else
      @obj = User.session
      @header = { user: @obj.login }
    end
  end

  def find_request_or_action
    @obj = BsRequest.find_by!(number: params[:request_number])
    @header = { request: @obj.number }
    find_diff_action
    return if performed?

    return unless params.key?(:parent_id)

    parent_comment = Comment.find_by(id: params[:parent_id])
    raise ActiveRecord::RecordNotFound, "Couldn't find the parent comment with ID #{params[:parent_id]}" if parent_comment.nil?

    # We don't want users to have to know if a parent comment is on a BsRequestAction or a BsRequest.
    # They can simply pass the BsRequest number and we handle this.
    parent_commentable = parent_comment.commentable
    return unless parent_commentable.is_a?(BsRequestAction) && @obj.id == parent_commentable.bs_request_id

    # We want to stick to the same commentable type as the parent comment for the new comment
    @obj = parent_commentable
  end

  # A diff comment goes to the action matching the target or the action id,
  # or to the only action the request has when neither is given. With more
  # than one action the caller has to name the target or the action id.
  def find_diff_action
    return unless action_selection_params?

    actions = @obj.bs_request_actions
    actions = actions.where(id: params[:action_id]) if params[:action_id].present?
    if params[:target_project] || params[:target_package]
      actions = actions.where(target_project: params[:target_project], target_package: params[:target_package])
    end

    raise ActiveRecord::RecordNotFound, "Couldn't find the request action#{target_suffix}" if actions.empty?

    if actions.size > 1
      render_error(status: 422, errorcode: 'ambiguous_request_action', message: ambiguous_actions_message)
      return
    end

    @obj = actions.first
  end

  # Whether the caller passed anything that selects a request action:
  # a target, an action id, or diff information for the single action
  # to be selected.
  def action_selection_params?
    params[:target_project] || params[:target_package] || params[:action_id] || diff_comment?
  end

  # A comment is a diff comment when it names a file in the diff and a line:
  # a file index or a filename, plus the line number. The target is not
  # what makes it a diff comment — a diff comment on a single-action request
  # needs no target at all.
  def diff_comment?
    params[:diff_line_number].present? && (params[:diff_file_index].present? || params[:filename].present?)
  end

  # The file index the comment is on: the caller passes it directly, or
  # names the file and the action resolves its index in the request diff.
  def diff_file_index
    return nil unless diff_comment? && @obj.respond_to?(:diff_file_index_for)

    params[:diff_file_index].presence || @obj.diff_file_index_for(params[:filename])
  end

  # Names the target the caller asked to match, for error messages.
  # Empty when the caller passed only diff information.
  def target_suffix
    return '' unless params[:target_project] || params[:target_package]

    " for #{params[:target_project]}/#{params[:target_package]}"
  end

  # The 422 message names the target when the caller gave one; otherwise it
  # tells the caller how to disambiguate.
  def ambiguous_actions_message
    return "Multiple request actions match#{target_suffix}" if params[:target_project] || params[:target_package]

    'Multiple request actions match; pass target_project and target_package to select one'
  end

  # The revisions a diff comment is made against. The caller may pin them
  # (source_rev/target_rev) as insurance that the comment is on the diff
  # they fetched; otherwise they come from the request action. Plain
  # comments and comments on anything but a request action carry none.
  def diff_revisions
    return [nil, nil] unless diff_comment? && @obj.respond_to?(:source_srcmd5) && @obj.respond_to?(:target_srcmd5)

    [params[:source_rev] || @obj.source_srcmd5, params[:target_rev] || @obj.target_srcmd5]
  end
end
