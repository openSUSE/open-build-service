class DownloadStat < ActiveRecord::Base


  belongs_to :db_project
  belongs_to :db_package
  belongs_to :repository
  belongs_to :architecture


end
