class PackageIssue < ApplicationRecord
  belongs_to :package
  belongs_to :issue

  def self.sync_relations(package, issues)
    retries=10
    begin
      PackageIssue.transaction do
        allissues=[]
        issues.map{|h| allissues += h.last}

        # drop not anymore existing relations
        PackageIssue.where("package_id = ? AND NOT issue_id IN (?)", package, allissues).lock(true).delete_all

        # create missing in an efficient way
        sql=ApplicationRecord.connection()
        (allissues - package.issues.to_ary).each do |i|
          sql.execute("INSERT INTO `package_issues` (`package_id`, `issue_id`) VALUES (#{package.id},#{i.id})")
        end

        # set change value for all
        issues.each do |pair|
          PackageIssue.where(package: package, issue: pair.last).lock(true).update_all(change: pair.first)
        end
      end
    rescue ActiveRecord::StatementInvalid, Mysql2::Error
      retries = retries - 1
      retry if retries > 0
    end
  end
end
