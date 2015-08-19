class AddPrimaryToRepositoryArchitectures < ActiveRecord::Migration

  class RepositoryArchitecture < ActiveRecord::Base
  end

  def change
    add_column :repository_architectures, :id, :int, null: false

    RepositoryArchitecture.transaction do
      rs = RepositoryArchitecture.all.to_a
      RepositoryArchitecture.delete_all

      id=1
      rs.each do |r|
        RepositoryArchitecture.create architecture_id: r.architecture_id, repository_id: r.repository_id, position: r.position, id: id
        id=id+1
      end
    end
    execute("alter table repository_architectures add PRIMARY KEY (`id`)")
    execute("alter table repository_architectures modify COLUMN id int(11) NOT NULL AUTO_INCREMENT")
  end
end
