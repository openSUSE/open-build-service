module BuildNewComment
  extend ActiveSupport::Concern

  def build_new_comment(commented, permitted_params)
    @comment = commented.comments.new(permitted_params)
    authorize @comment, :create?
    User.session.comments << @comment
  end
end
