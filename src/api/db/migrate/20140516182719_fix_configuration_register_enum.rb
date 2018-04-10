# frozen_string_literal: true
class FixConfigurationRegisterEnum < ActiveRecord::Migration[4.2]
  def change
    execute "alter table configurations modify column configurations.registration enum('allow', 'confirmation', 'deny') DEFAULT 'allow';"
  end
end
