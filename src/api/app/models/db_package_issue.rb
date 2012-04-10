class DbPackageIssue < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :issue

  attr_accessible :issue, :change

end
