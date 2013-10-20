module HasComments

  def save_comment
    require_login || return

    required_parameters :body
    required_parameters :title unless params[:parent_id]

    obj = comment_object.api_obj
    comment = obj.comments.build(title: params[:title], body: params[:body], parent_id: params[:parent_id])
    comment.user = User.current
    comment.type = obj.comment_class
    comment.save!

    respond_to do |format|
      format.js { render json: 'ok' }
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
        @all_comments[:children] << [com.title, com.body, com.user.login, com.parent_id, com.id, com.created_at]
      else
        @all_comments[:parents] << [com.title, com.body, com.id, com.user.login, com.created_at]
      end
    end

    @all_comments[:parents].sort_by! { |c| c[4] } # sorting by created_at
    @all_comments[:children].sort_by! { |c| c[4] } # sorting by created_at

    thread_comments
  end

  def thread_comments
    @comments = []
    # now pushing sorted and final list of first/top/parent level comments into to a hash to
    @all_comments[:parents].each do |first_level|
      @comments << {
          created_at: first_level[4],
          id: first_level[2],
          title: first_level[0],
          body: first_level[1],
          parent_id: nil,
          user: first_level[3],
          children: find_children(first_level[2])
      }
    end
  end

  def find_children(parent_id = nil)
    return [] unless parent_id
    current_children = []

    # get children of current top comment
    child_comments = @all_comments[:children].select do |c|
      c[3] == parent_id
    end

    # pushing children coments into hash

    child_comments.each do |child|
      current_children << {
          created_at: child[5],
          id: child[4],
          title: child[0],
          body: child[1],
          parent_id: child[3],
          user: child[2],
          children: find_children(child[4])
      }
    end
    return current_children
  end

end