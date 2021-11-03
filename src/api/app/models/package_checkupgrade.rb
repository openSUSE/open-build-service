class PackageCheckUpgrade < ApplicationRecord
  belongs_to :package
  belongs_to :checkupgrade


  #FIXME

end

#FIXME
# == Schema Information
#
# Table name: package_issues
#
#  id         :integer          not null, primary key
#  change     :string
#  issue_id   :integer          not null, indexed, indexed => [package_id]
#  package_id :integer          not null, indexed => [issue_id]
#
# Indexes
#
#  index_package_issues_on_issue_id                 (issue_id)
#  index_package_issues_on_package_id_and_issue_id  (package_id,issue_id)
#
# Foreign Keys
#
#  package_issues_ibfk_1  (package_id => packages.id)
#  package_issues_ibfk_2  (issue_id => issues.id)
#
