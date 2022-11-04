module Webui
  module Packages
    class BadgeController < Packages::MainController
      before_action :set_project
      before_action :set_package

      def show
        results = @package.buildresult(@project, false, true).results[@package.name]
        results = results.select { |r| r.architecture == params[:architecture] } if params[:architecture]
        results = results.select { |r| r.repository == params[:repository] } if params[:repository]
        badge = Badge.new(params[:type], results)
        send_data(badge.xml, type: 'image/svg+xml', disposition: 'inline')
      end
    end
  end
end
