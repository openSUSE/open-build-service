class ChangeConfigurationObsUrlDefault < ActiveRecord::Migration[5.1]
  def change
    change_column_default(:configurations, :obs_url, from: NULL, to: 'https://unconfigured.openbuildservice.org')
  end
end
