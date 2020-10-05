class Webui::CommentSnippetsController < Webui::WebuiController
  before_action :require_login
  before_action :check_displayed_user

  def index
    @comment_snippets = CommentSnippet.limit(10).all
    render :index
  end

  def create
    @comment_snippet = CommentSnippet.new(permitted_params)
    User.session!.comment_snippets << @comment_snippet

    status = if @comment_snippet.save
               flash.now[:success] = 'Comment snippet created successfully.'
               :ok
             else
               flash.now[:error] = "Failed to create comment snippet: #{comment.errors.full_messages.to_sentence}."
               :unprocessable_entity
             end
    render(partial: 'webui/comment_snippets/comment_snippets_list')
  end

  private

  def permitted_params
    params.require(:comment_snippet).permit(:title, :body)
  end
end
