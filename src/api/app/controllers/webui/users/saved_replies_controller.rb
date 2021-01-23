module Webui
  module Users
    class SavedRepliesController < WebuiController
      before_action :kerberos_auth

      def index
        @saved_replies = User.session.saved_replies
      end

      def new
        @saved_reply = User.session.saved_replies.new
      end

      def create
        @saved_reply = User.session.saved_replies.new(saved_reply_params)
        if @saved_reply.valid? && @saved_reply.save
          flash[:success] = "Reply was created successfully"
          redirect_to action: 'index'
        else
          flash[:error] = "Failed to save reply. #{@saved_reply.errors.full_messages.to_sentence}."
          render :new
        end
      end

      def destroy
      end

      private

      def saved_reply_params
        params.require(:saved_reply).permit(:title,:body)
      end
    end
  end
end
