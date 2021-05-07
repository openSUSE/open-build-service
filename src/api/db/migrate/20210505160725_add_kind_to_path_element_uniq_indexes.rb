class AddKindToPathElementUniqIndexes < ActiveRecord::Migration[6.0]
  def up
    remove_foreign_key :path_elements, name: 'path_elements_ibfk_1'
    remove_index :path_elements, name: 'parent_repository_index'
    add_index :path_elements, ['parent_id', 'repository_id', 'kind'], name: 'parent_repository_index', unique: true
    add_foreign_key 'path_elements', 'repositories', column: 'parent_id', name: 'path_elements_ibfk_1'
  end

  def down
    remove_foreign_key :path_elements, name: 'path_elements_ibfk_1'
    remove_index :path_elements, name: 'parent_repository_index'
    add_index :path_elements, ['parent_id', 'repository_id'], name: 'parent_repository_index', unique: true
    add_foreign_key 'path_elements', 'repositories', column: 'parent_id', name: 'path_elements_ibfk_1'
  end
end
