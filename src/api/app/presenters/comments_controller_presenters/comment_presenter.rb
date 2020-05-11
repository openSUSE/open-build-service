module CommentsControllerPresenters
  class CommentPresenter
    def initialize(comment, obj_is_user)
      @comment = comment
      @obj_is_user = obj_is_user
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
      comment.body.delete("\u0000")
    end

    private

    attr_accessor :comment
  end
end
