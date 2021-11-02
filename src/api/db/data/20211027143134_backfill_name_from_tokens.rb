# frozen_string_literal: true

class BackfillNameFromTokens < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    Token.unscoped.in_batches do |relation|
      # rubocop:disable Rails/SkipsModelValidations
      relation.update_all name: ''
      # rubocop:enable Rails/SkipsModelValidations
      sleep(0.01) # throttle
    end
  end
end
