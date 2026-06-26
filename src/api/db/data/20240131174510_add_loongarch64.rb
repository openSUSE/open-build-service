class AddLoongarch64 < ActiveRecord::Migration[7.0]
  def up
    Architecture.where(name: 'loongarch64').first_or_create
  end

  def down
    Architecture.find_by_name('loongarch64').destroy
  end
end
