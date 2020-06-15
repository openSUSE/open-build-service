# render_xml function implemented as a view in models/<class.name>
# to use this mixin, generate a app/views/model/_my_model.xml.builder file
# and use my_model to access the model instead of self
module CanRenderModel
  def render_xml(locals = {})
    locals[:my_model] = self
    ApplicationController.render(partial: "models/#{self.class.name.underscore}", locals: locals, formats: [:xml])
  end
end
