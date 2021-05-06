class AddKindToPathElementUniqIndexes < ActiveRecord::Migration[6.0]
  def up
    safety_assured { execute 'SET FOREIGN_KEY_CHECKS=0;' }
    remove_index :path_elements, name: 'parent_repository_index'
    add_index :path_elements, ['parent_id', 'repository_id', 'kind'], name: 'parent_repository_index', unique: true
  ensure
    safety_assured { execute 'SET FOREIGN_KEY_CHECKS=1;' }
  end

  def down
    safety_assured { execute 'SET FOREIGN_KEY_CHECKS=0;' }
    remove_index :path_elements, name: 'parent_repository_index'
    add_index :path_elements, ['parent_id', 'repository_id'], name: 'parent_repository_index', unique: true
  ensure
    safety_assured { execute 'SET FOREIGN_KEY_CHECKS=1;' }
  end
end
