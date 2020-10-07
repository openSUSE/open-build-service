class Webui::CommentSnippetsController < Webui::WebuiController
  before_action :require_login
  before_action :check_displayed_user

  def index
    comment_snippets = User.session.comment_snippets.limit(10).all

    render :index, locals: { comment_snippets: comment_snippets }
  end

  def create
    comment_snippet = CommentSnippet.new(permitted_params)
    User.session!.comment_snippets << comment_snippet
    comment_snippets = User.session.comment_snippets

    status = if comment_snippet.save
               flash.now[:success] = 'Reply created successfully.'
               :ok
             else
               flash.now[:error] = "Failed to create reply: #{comment_snippet.errors.full_messages.to_sentence}."
               :unprocessable_entity
             end

    respond_to do |format|
      format.html do
        render(partial: 'webui/comment_snippets/comment_snippets_list',
               locals: { comment_snippets: comment_snippets },
               status: status)
      end
    end
  end

  def update
    comment_snippet = CommentSnippet.find(params[:id])
    authorize comment_snippet, :update?
    comment_snippet.assign_attributes(permitted_params)
    comment_snippets = User.session.comment_snippets

    status = if comment_snippet.save
               flash.now[:success] = 'Reply updated successfully.'
               :ok
             else
               flash.now[:error] = "Failed to update reply: #{comment_snippet.errors.full_messages.to_sentence}."
               :unprocessable_entity
             end

    respond_to do |format|
      format.html do
        render(partial: 'webui/comment_snippets/comment_snippets_list',
               locals: { comment_snippets: comment_snippets },
               status: status)
      end
    end
  end

  def destroy
    comment_snippet = CommentSnippet.find(params[:id])
    authorize comment_snippet, :destroy?
    comment_snippets = User.session.comment_snippets

    status = if comment_snippet.destroy
               flash.now[:success] = 'Reply deleted successfully.'
               :ok
             else
               flash.now[:error] = "Failed to delete reply: #{comment_snippet.errors.full_messages.to_sentence}."
               :unprocessable_entity
             end

    respond_to do |format|
      format.html do
        render(partial: 'webui/comment_snippets/comment_snippets_list',
               locals: { comment_snippets: comment_snippets },
               status: status)
      end
    end
  end

  private

  def permitted_params
    params.require(:comment_snippet).permit(:title, :body)
  end
end
