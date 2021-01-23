module Webui
  module Users
    class SavedRepliesController < WebuiController
      before_action :kerberos_auth
      before_action :set_saved_reply_by_id, only: [:edit, :update, :destroy]

      def index
        @saved_replies = User.session.saved_replies
      end

      def new
        @saved_reply = User.session.saved_replies.new
      end

      def create
        @saved_reply = User.session.saved_replies.new(saved_reply_params)
        if @saved_reply.valid? && @saved_reply.save
          flash[:success] = 'Reply was created successfully'
          redirect_to saved_replies_path
        else
          flash[:error] = "Failed to save reply. #{@saved_reply.errors.full_messages.to_sentence}."
          render :new
        end
      end

      def edit ; end

      def update
        if @saved_reply.update(saved_reply_params)
          flash[:success] = 'Reply was updated successfully'
          redirect_to saved_replies_path
        else
          flash[:error] = "Failed to update reply. #{@saved_reply.errors.full_messages.to_sentence}."
          render :edit
        end
      end

      def destroy
        @saved_reply.destroy
        flash[:success] = 'Reply was successfully removed.'
        redirect_to saved_replies_path
      end

      private

      def saved_reply_params
        params.require(:saved_reply).permit(:title, :body)
      end

      def set_saved_reply_by_id
        @saved_reply = User.session.saved_replies.find(params[:id])
      end
    end
  end
end
