module Webui::HasComments
  # This is a nice but useless reimplementation of nested objects. Good work but nahhhhh
  def save_comment
    require_login || return

    comment = main_object.comments.build(body: params[:body], parent_id: params[:parent_id])
    comment.user = User.current

    respond_to do |format|
      if comment.save
        format.html { redirect_back(fallback_location: root_path, notice: 'Comment was successfully created.') }
        format.json { render json: 'ok' }
      else
        format.html { redirect_back(fallback_location: root_path, error: "Comment can't be saved: #{comment.errors.full_messages.to_sentence}.") }
        format.json { render json: comment.errors, status: :unprocessable_entity }
      end
    end
  end
end
