class AddLocalPermissions < ActiveRecord::Migration
  def self.up
    ch_pro = StaticPermission.create :title => "change_project"
    ch_pac = StaticPermission.create :title => "change_package"
    cr_pro = StaticPermission.create :title => "create_project"
    cr_pac = StaticPermission.create :title => "create_package"

    admin = Role.find_by_title "Admin"
    maint = Role.find_by_title "maintainer"
    for role in [admin, maint] do
      role.static_permissions << [ch_pro, ch_pac, cr_pro, cr_pac]
    end
  end

  def self.down
  end
end
