class PackageIssue < ActiveRecord::Base
  belongs_to :package
  belongs_to :issue

  attr_accessible :issue, :change

end
