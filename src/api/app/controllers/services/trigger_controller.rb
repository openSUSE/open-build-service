class Services::TriggerController < Services::BaseController
  validate_action runservice: { method: :post, response: :status }
  before_action :receive_token
  before_action :set_package

  def runservice
    return unless @pkg
    # execute the service in backend
    path = @pkg.source_path
    params = { cmd: 'runservice', comment: 'runservice via trigger', user: @token.user.login }
    path << build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend(path)

    @pkg.sources_changed
  end
end
