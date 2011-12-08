class DbPackageIssue < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :issue

end
