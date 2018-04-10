# frozen_string_literal: true
module Webui
  module Users
    class RssTokensController < WebuiController
      before_action :require_login

      def create
        token = User.current.rss_token
        if token
          flash[:success] = 'Successfully re-generated your RSS feed url'
          token.regenerate_string
          token.save
        else
          flash[:success] = 'Successfully generated your RSS feed url'
          User.current.create_rss_token
        end
        redirect_back(fallback_location: user_notifications_path)
      end
    end
  end
end
