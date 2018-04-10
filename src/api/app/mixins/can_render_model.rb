# frozen_string_literal: true
# render_xml function implemented as a view in models/<class.name>
# to use this mixin, generate a app/views/model/_my_model.xml.builder file
# and use my_model to access the model instead of self
module CanRenderModel
  def render_xml(locals = {})
    # FIXME: Hand me the revolver please...
    partial = self.class.name == 'RemoteProject' ? 'Project' : self.class.name
    action_view = ActionView::Base.new(Rails.configuration.paths['app/views'])
    locals[:my_model] = self
    action_view.render partial: "models/#{partial.underscore}", formats: [:xml],
                       locals: locals
  end
end
