module Webui::ValidationHelper
  def classes_with_validation(model, field)
    if model.errors.where(field).any?
      'form-control is-invalid'
    else
      'form-control'
    end
  end
end
