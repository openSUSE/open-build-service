class Updateinfo < ActiveRecord::Base

  belongs_to :package, foreign_key: :package_id
  belongs_to :repository, foreign_key: :repository_id

end

