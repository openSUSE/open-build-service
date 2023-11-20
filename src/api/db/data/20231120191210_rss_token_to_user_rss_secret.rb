# frozen_string_literal: true

class RssTokenToUserRssSecret < ActiveRecord::Migration[7.0]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    Token.where(type: 'Token::Rss').in_batches do |relation|
      relation.each do |token|
        token.executor.update_columns(rss_secret: token.string) if token.executor.rss_secret.blank?
      end
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
