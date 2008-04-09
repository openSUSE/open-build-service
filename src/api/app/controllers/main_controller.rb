class MainController < ApplicationController
  layout "rbac"
  skip_before_filter :extract_user, :only => [:lastevents]

  # GET /lastevents?:start&filter&filter
  def lastevents
    valid_http_methods :get

    #XXX rails only recognizes multiple parameters when they end with []
    #XXX so I can't use build_query_from_hash here
    path = request.path
    path += "?#{request.query_string}" unless request.query_string.empty?

    logger.info "streaming #{path}"

    render :status => 200, :text => Proc.new {|request,output|
      backend_request = Net::HTTP::Get.new(path)
      response = Net::HTTP.start(SOURCE_HOST,SOURCE_PORT) do |http|
        http.request(backend_request) do |response|
          response.read_body do |chunk|
            output.write chunk
          end
        end
      end
    }
    return
  end
end
