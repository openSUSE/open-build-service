class DropDownloadStats < ActiveRecord::Migration
  def change
    drop_table "download_stats"
  end
end
