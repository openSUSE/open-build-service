class PackageIssue < ApplicationRecord
  belongs_to :package
  belongs_to :issue

  scope :open_issues_of_owner, ->(owner_id) { joins(:issue).where(issues: { state: 'OPEN', owner_id: owner_id}) }
  scope :with_patchinfo, lambda {
    joins('LEFT JOIN package_kinds ON package_kinds.package_id = package_issues.package_id').where('package_kinds.kind = "patchinfo"')
  }

  def self.sync_relations(package, issues)
    retries = 10
    begin
      PackageIssue.transaction do
        allissues = []
        issues.map { |h| allissues += h.last }

        # drop not anymore existing relations
        PackageIssue.where("package_id = ? AND NOT issue_id IN (?)", package, allissues).lock(true).delete_all

        # create missing in an efficient way
        sql = ApplicationRecord.connection
        (allissues - package.issues.to_ary).each do |i|
          sql.execute("INSERT INTO `package_issues` (`package_id`, `issue_id`) VALUES (#{package.id},#{i.id})")
        end

        # set change value for all
        issues.each do |pair|
          # rubocop:disable Rails/SkipsModelValidations
          PackageIssue.where(package: package, issue: pair.last).lock(true).update_all(change: pair.first)
          # rubocop:enable Rails/SkipsModelValidations
        end
      end
    rescue ActiveRecord::StatementInvalid, Mysql2::Error
      retries -= 1
      retry if retries > 0
    end
  end
end

# == Schema Information
#
# Table name: package_issues
#
#  id         :integer          not null, primary key
#  package_id :integer          not null, indexed => [issue_id]
#  issue_id   :integer          not null, indexed, indexed => [package_id]
#  change     :string(7)
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
