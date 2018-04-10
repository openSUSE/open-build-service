# frozen_string_literal: true

class AddImageReferenceToPackages < ActiveRecord::Migration[5.0]
  def change
    add_reference :packages, :kiwi_image, foreign_key: true
  end
end
