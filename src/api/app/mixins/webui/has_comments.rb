module Webui::HasComments

  def save_comment
    require_login || return

    required_parameters :body

    obj = main_object.api_obj
    comment = obj.comment_class.new(body: params[:body], parent_id: params[:parent_id])
    obj.comments << comment
    comment.user = User.current
    comment.save!

    respond_to do |format|
      format.js do
        render json: 'ok'
      end
      format.html do
        flash[:notice] = 'Comment added successfully'
      end
    end
    redirect_to :back
  end

  protected

  def sort_comments(comments)
    @all_comments = Hash.new
    @all_comments[:parents] = []
    @all_comments[:children] = []

    # separate parents from children. How cruel, I know.
    comments.each do |com|
      # No valid parent
      if !com.parent_id.nil? && Comment.exists?(com.parent_id)
        @all_comments[:children] << [com.body, com.user.login, com.parent_id, com.id, com.created_at]
      else
        @all_comments[:parents] << [com.body, com.id, com.user.login, com.created_at]
      end
    end

    @all_comments[:parents].sort_by! { |c| c[3] } # sorting by created_at
    @all_comments[:children].sort_by! { |c| c[3] } # sorting by created_at

    thread_comments
  end

  def thread_comments
    @comments = []
    # now pushing sorted and final list of first/top/parent level comments into to a hash to
    @all_comments[:parents].each do |first_level|
      @comments << {
          created_at: first_level[3],
          id: first_level[1],
          body: first_level[0],
          parent_id: nil,
          user: first_level[2],
          children: find_children(first_level[1])
      }
    end
  end

  def find_children(parent_id = nil)
    return [] unless parent_id
    current_children = []

    # get children of current top comment
    child_comments = @all_comments[:children].select do |c|
      c[2] == parent_id
    end

    # pushing children coments into hash

    child_comments.each do |child|
      current_children << {
          created_at: child[4],
          id: child[3],
          body: child[0],
          parent_id: child[2],
          user: child[1],
          children: find_children(child[3])
      }
    end
    return current_children
  end

end
