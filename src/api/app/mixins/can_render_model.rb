# render_xml function implemented as a view in models/<class.name>
# to use this mixin, generate a app/views/model/_my_model.xml.builder file
# and use my_model to access the model instead of self
module CanRenderModel
  def render_xml(locals = {})
    action_view = ActionView::Base.new(Rails.configuration.paths['app/views'].to_ary)
    locals[:my_model] = self
    action_view.render partial: "models/#{self.class.name.underscore}", formats: [:xml],
                       locals: locals
  end
end
