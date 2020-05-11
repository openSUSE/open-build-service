class ChangeConfigurationObsUrlDefault < ActiveRecord::Migration[5.1]
  def change
    change_column_default(:configurations, :obs_url, from: :null, to: 'https://unconfigured.openbuildservice.org')
  end
end
