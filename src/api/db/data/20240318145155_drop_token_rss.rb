# frozen_string_literal: true

class DropTokenRss < ActiveRecord::Migration[7.0]
  def up
    Token.where(type: 'Token::Rss').delete_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
