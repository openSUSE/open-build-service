# frozen_string_literal: true

AjaxDatatablesRails.configure do |config|
  # available options for db_adapter are: :pg, :mysql, :mysql2, :sqlite, :sqlite3
  # config.db_adapter = :pg
  config.db_adapter = :mysql2

  # Or you can use your rails environment adapter if you want a generic dev and production
  # config.db_adapter = Rails.configuration.database_configuration[Rails.env]['adapter'].to_sym
end
