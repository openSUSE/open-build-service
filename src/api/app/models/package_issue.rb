class PackageIssue < ActiveRecord::Base
  belongs_to :package
  belongs_to :issue
end
