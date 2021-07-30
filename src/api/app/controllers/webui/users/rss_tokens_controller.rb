module Webui
  module Users
    class RssTokensController < WebuiController
      # TODO: Remove this when we'll refactor kerberos_auth
      before_action :kerberos_auth

      after_action :verify_authorized

      def create
        token = authorize(::Token::Rss.find_or_initialize_by(user: User.session))
        if token.persisted?
          flash[:success] = 'Successfully re-generated your RSS feed url'
          token.regenerate_string
        else
          flash[:success] = 'Successfully generated your RSS feed url'
        end
        token.save

        redirect_back(fallback_location: my_subscriptions_path)
      end
    end
  end
end
