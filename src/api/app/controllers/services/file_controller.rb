class Services::FileController < Services::BaseController
  before_action :receive_token, :set_package

  def create
    return unless @pkg
    Package.verify_file!(@pkg, '_service', request.raw_post.to_s)
    path = Package.source_path(@pkg.project.name, @pkg.name, '_service')
    params = { user: @token.user.login }
    path += build_query_from_hash(params, [:user])
    pass_to_backend(path)
    @pkg.sources_changed(wait_for_update: '_service')
  end
end
