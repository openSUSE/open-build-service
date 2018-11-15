class SanitizeReviews < ActiveRecord::Migration[5.2]
  # Find reviews that have multiple review targets (e.g. by_user and by_group)
  # and split them up. So that reviews are per review target.
  def up
    Review.where.not(by_group: nil, by_user: nil, by_project: nil).find_each do |review|
      # The package / project review
      review.dup.update!(by_group: nil, group_id: nil, by_user: nil, user_id: nil)
      # The group review
      review.dup.update!(by_user: nil, user_id: nil, by_project: nil, project_id: nil, by_package: nil, package_id: nil)
      # Te user review
      review.update!(by_group: nil, group_id: nil, by_project: nil, project_id: nil, by_package: nil, package_id: nil)
    end
    Review.where.not(by_group: nil, by_user: nil).find_each do |review|
      # The group review
      review.dup.update!(by_user: nil, user_id: nil)
      # Te user review
      review.update!(by_group: nil, group_id: nil)
    end
    Review.where.not(by_group: nil, by_project: nil).find_each do |review|
      # The group review
      review.dup.update!(by_project: nil, project_id: nil, by_package: nil, package_id: nil)
      # The package / project review
      review.update!(by_group: nil, group_id: nil)
    end
    Review.where.not(by_user: nil, by_project: nil).find_each do |review|
      # Te user review
      review.dup.update!(by_project: nil, project_id: nil, by_package: nil, package_id: nil)
      # The package / project review
      review.update!(by_user: nil, user_id: nil)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
