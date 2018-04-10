# frozen_string_literal: true
class ConvertTokensToServiceTokens < ActiveRecord::Migration[5.1]
  def up
    Token.where(type: nil).update_all(type: 'Token::Service')
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
