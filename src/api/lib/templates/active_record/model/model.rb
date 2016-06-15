<% module_namespacing do -%>
# TODO: Please overwrite this comment with something explaining the model target
class <%= class_name %> < <%= parent_class_name.classify %>
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes
<% attributes.select(&:token?).each do |attribute| -%>
  has_secure_token<% if attribute.name != "token" %> :<%= attribute.name %><% end %>
<% end -%>
<% if attributes.any?(&:password_digest?) -%>
  has_secure_password
<% end -%>

  #### Associations macros (Belongs to, Has one, Has many)
  <% attributes.select(&:reference?).each do |attribute| -%>
    belongs_to :<%= attribute.name %><%= ', polymorphic: true' if attribute.polymorphic? %><%= ', required: true' if attribute.required? %>
  <% end -%>

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private


  #### Instance methods (public and then protected/private)

  #### Alias of methods
  
end
<% end -%>
