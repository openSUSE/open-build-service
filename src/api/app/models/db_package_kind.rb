
class DbPackageKind < ActiveRecord::Base
  belongs_to :db_package

  attr_accessible :kind
end

