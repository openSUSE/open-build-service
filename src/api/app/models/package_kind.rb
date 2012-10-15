
class PackageKind < ActiveRecord::Base
  belongs_to :package

  attr_accessible :kind
end

