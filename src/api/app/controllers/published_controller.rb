class PublishedController < ApplicationController
  def index
    prj = Project.find_by_name!(params[:project])

    # binarydownload is no security feature (read the docu :)
    if prj.disabled_for?('binarydownload', params[:repository], params[:arch]) && !User.current.can_download_binaries?(prj)
      render_error status: 403, errorcode: 'download_binary_no_permission',
                   message: "No permission for binaries from project #{params[:project]}"
      return
    end
    pass_to_backend
  end
end
