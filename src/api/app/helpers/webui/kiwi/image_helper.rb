module Webui::Kiwi::ImageHelper
  include Webui::ProjectHelper

  def kiwi_image_breadcrumb(kiwi_image, *args)
    @project = kiwi_image.package.try(:project)
    return unless @project

    args.insert(0, link_to_if(params['action'] != 'show', 'Image',
                              kiwi_image_path(id: kiwi_image)))
    project_bread_crumb( *args )
  end
end
