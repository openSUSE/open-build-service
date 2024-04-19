module Webui
  module Packages
    class BadgeController < Packages::MainController
      before_action :set_project
      before_action :set_package

      def show
        results = @package.buildresult(@project, false, true).results[@package.name]
        results = results.select { |r| r.architecture == params[:architecture] } if params[:architecture]
        results = results.select { |r| r.repository == params[:repository] } if params[:repository]
        # discard results with excluded and disabled status
        results = results.reject { |r| Buildresult.new(r.code).refused_status? }
        # discard possible disabled results with previous failed status
        results = results.reject { |r| @package.disabled_for?('build', r.repository, r.architecture) } unless results.nil? # discard disabled
        badge = Badge.new(params[:type], results)
        send_data(badge.xml, type: 'image/svg+xml', disposition: 'inline')
      end
    end
  end
end
