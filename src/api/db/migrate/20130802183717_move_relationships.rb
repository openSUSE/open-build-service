class MoveRelationships < ActiveRecord::Migration
  class PackageUserRoleRelationship < ActiveRecord::Base; end
  class PackageGroupRoleRelationship < ActiveRecord::Base; end
  class ProjectUserRoleRelationship < ActiveRecord::Base; end
  class ProjectGroupRoleRelationship < ActiveRecord::Base; end
  class Relationship < ActiveRecord::Base; end

  def up
    Relationship.transaction do
      PackageUserRoleRelationship.all.each do |r|
        Relationship.create(role_id: r.role_id, user_id: r.bs_user_id, package_id: r.db_package_id)
      end
      PackageGroupRoleRelationship.all.each do |r|
        Relationship.create(role_id: r.role_id, group_id: r.bs_group_id, package_id: r.db_package_id)
      end
      ProjectUserRoleRelationship.all.each do |r|
        Relationship.create(role_id: r.role_id, user_id: r.bs_user_id, project_id: r.db_project_id)
      end
      ProjectGroupRoleRelationship.all.each do |r|
        Relationship.create(role_id: r.role_id, group_id: r.bs_group_id, project_id: r.db_project_id)
      end
    end
  end

  def down
    Relationship.destroy_all
  end
end
