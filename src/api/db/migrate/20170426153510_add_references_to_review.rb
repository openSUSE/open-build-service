class AddReferencesToReview < ActiveRecord::Migration[5.0]
  def up
    start = Time.now
    add_reference(:reviews, :entity, polymorphic: true)

    tmp = Review.where("by_user is not null").distinct(:by_user).pluck(:by_user)
    User.where(login: tmp).each do |user|
      execute "UPDATE reviews SET entity_id = #{user.id}, entity_type = 'User' WHERE by_user = '#{user.login}'"
    end

    tmp = Review.where("by_group is not null").distinct(:by_group).pluck(:by_group)
    Group.where(title: tmp).each do |group|
      execute "UPDATE reviews SET entity_id = #{group.id}, entity_type = 'Group' WHERE by_group = '#{group.title}'"
    end

    tmp = Review.where("by_project is not null AND by_package IS NULL").distinct(:by_project).pluck(:by_project)
    Project.where(name: tmp).each do |project|
      execute "UPDATE reviews SET entity_id = #{project.id}, entity_type = 'Project' WHERE by_project = '#{project.name}' AND by_package IS NULL"
    end

    tmp = Review.where("by_package is not null").pluck(:by_package)
    Package.includes(:project).where(name: tmp).each do |package|
      execute "UPDATE reviews SET entity_id = #{package.id}, entity_type = 'Package' WHERE by_package = '#{package.name}' AND by_project = '#{package.project.name}'"
    end

    puts "AddReferencesToReview took #{start - Time.now}"
  end

  def down
    remove_reference(:reviews, :entity, polymorphic: true)
  end
end
