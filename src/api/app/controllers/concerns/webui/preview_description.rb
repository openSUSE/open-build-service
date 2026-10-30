module Webui::PreviewDescription
  extend ActiveSupport::Concern

  # POST /<resource>/preview_description
  def preview_description
    skip_authorization

    markdown = helpers.render_as_markdown(params[controller_name.singularize][:description])
    respond_to do |format|
      format.json { render json: { markdown: markdown } }
    end
  end
end
