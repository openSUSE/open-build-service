class MakeAttribNamespaceNameRequired < ActiveRecord::Migration[7.2]
  def change
    change_column_null :attrib_namespaces, :name, false
  end
end
