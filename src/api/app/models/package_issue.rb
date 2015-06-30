class PackageIssue < ActiveRecord::Base
  belongs_to :package
  belongs_to :issue

  def self.sync_relations(package, issues)
    package.with_lock do
      PackageIssue.transaction do
        allissues=[]
        issues.map{|h| allissues += h.last}

        # drop not anymore existing relations
        PackageIssue.where("package_id = ? AND NOT issue_id IN (?)", package, allissues).delete_all

        # create missing in an efficient way
        sql=ActiveRecord::Base.connection()
        (allissues - package.issues.to_ary).each do |i|
          sql.execute("INSERT INTO `package_issues` (`package_id`, `issue_id`) VALUES (#{package.id},#{i.id})")
        end

        # set change value for all
        issues.each do |pair|
          PackageIssue.where(package: package, issue: pair.last).update_all(change: pair.first)
        end
      end
    end
  end
end
