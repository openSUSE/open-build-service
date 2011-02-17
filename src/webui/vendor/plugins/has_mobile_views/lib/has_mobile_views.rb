module ActionController
  module HasMobileViews
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def has_mobile_views opts = {}
        class_eval do
          send :include, InstanceMethods

          helper_method :mobile_request?
          helper_method :mobile_browser?

          before_filter :prepend_view_path_if_mobile
        end
      end
    end

    module InstanceMethods
      def prepend_view_path_if_mobile
        if mobile_request?
          prepend_view_path 'app/mobile_views'
        end
      end

      def mobile_request?
        session[:mobile_view] = mobile_browser? if session[:mobile_view].nil?
        if params[:force_view] == 'mobile' && !session[:mobile_view]
          session[:mobile_view] = true
        elsif params[:force_view] == 'normal' && session[:mobile_view]
          session[:mobile_view] = false
        end
        session[:mobile_view]
      end

      def mobile_browser?
        # enable when ready
        # request.env["HTTP_USER_AGENT"] && !!request.env["HTTP_USER_AGENT"][/(iPhone|iPod|Android)/]
        false
      end
    end
  end
end

ActionController::Base.send(:include, ActionController::HasMobileViews)
