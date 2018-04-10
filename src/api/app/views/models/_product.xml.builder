# frozen_string_literal: true

xml.product(name: my_model.name,
            originproject: my_model.package.project.name,
            originpackage: my_model.package.name) do

  xml.cpe(my_model.cpe)

  xml.version(my_model.version)         if my_model.version
  xml.baseversion(my_model.baseversion) if my_model.baseversion
  xml.patchlevel(my_model.patchlevel)   if my_model.patchlevel
  xml.release(my_model.release)         if my_model.release
end
