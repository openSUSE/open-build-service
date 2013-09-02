class Webui::PackagesController < Webui::BaseController

  include ParsePackageDiff

  before_action :require_package

  def require_package
    required_parameters :project_id, :id

    @package = Package.get_by_project_and_name(params[:project_id], params[:id])
    return true
  end

  def find_last_req
    if @oproject and @opackage
      last_req = BsRequestAction.where(target_project: @oproject,
                                       target_package: @opackage,
                                       source_project: @package.project.name,
                                       source_package: @package.name).order(:bs_request_id).last
      return nil unless last_req
      last_req = last_req.bs_request
      if last_req.state != :declined
        return nil # ignore all !declined
      end
      return last_req.webui_infos(diffs: false)
    end
    nil
  end

  class DiffError < APIException
  end

  def get_diff(path)
    begin
      @rdiff = ActiveXML.transport.direct_http URI(path + '&expand=1'), method: "POST", timeout: 10
    rescue ActiveXML::Transport::Error => e
      @infos[:alert] = e.summary
      begin
        @rdiff = ActiveXML.transport.direct_http URI(path + '&expand=0'), method: "POST", timeout: 10
      rescue ActiveXML::Transport::Error => e
        raise DiffError.new "Error getting diff: " + e.summary
      end
    end
  end

  def rdiff
    @infos = {}
    @infos[:last_rev] = @package.dir_hash['rev']
    @infos[:linkinfo] = @package.linkinfo
    @oproject, @opackage = params[:oproject], params[:opackage]

    @infos[:last_req] = find_last_req

    @infos[:rev] = params[:rev] || @infos[:last_rev]

    query = {'cmd' => 'diff', 'view' => 'xml', 'withissues' => 1}
    [:orev, :opackage, :oproject].each do |k|
      query[k] = params[k] unless params[k].blank?
    end
    query[:rev] = @infos[:rev] if @infos[:rev]
    get_diff @package.source_path + "?#{query.to_query}"

    # we only look at [0] because this is a generic function for multi diffs - but we're sure we get one
    filenames = sorted_filenames_from_sourcediff(@rdiff)[0]
    @infos[:files] = filenames['files']
    @infos[:filenames] = filenames['filenames']

    render json: @infos
  end

end
