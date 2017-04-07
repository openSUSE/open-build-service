class FixDodRepotype < ActiveRecord::Migration[5.0]
  def up
    DownloadRepository.where(repotype: "rpmmd").update(repotype: "rpm-md")
  end
  def down
    DownloadRepository.where(repotype: "rpm-md").update(repotype: "rpmmd")
  end
end
