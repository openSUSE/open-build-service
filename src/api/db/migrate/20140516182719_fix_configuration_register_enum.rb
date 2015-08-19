class FixConfigurationRegisterEnum < ActiveRecord::Migration

  def change
    execute "alter table configurations modify column configurations.registration enum('allow', 'confirmation', 'deny') DEFAULT 'allow';"
  end
end
