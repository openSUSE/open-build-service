module Webui
  module Users
    class SavedRepliesController < WebuiController
      before_action :kerberos_auth

      def new
      end

      def index
        @saved_replies = User.session.saved_replies
      end

      def destroy
      end

      private

    end
  end
end
