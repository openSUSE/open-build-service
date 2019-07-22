# typed: false
module Webui
  module Users
    class RssTokensController < WebuiController
      before_action :require_login

      def create
        token = User.session!.rss_token
        if token
          flash[:success] = 'Successfully re-generated your RSS feed url'
          token.regenerate_string
          token.save
        else
          flash[:success] = 'Successfully generated your RSS feed url'
          User.session!.create_rss_token
        end
        redirect_back(fallback_location: user_notifications_path)
      end
    end
  end
end
