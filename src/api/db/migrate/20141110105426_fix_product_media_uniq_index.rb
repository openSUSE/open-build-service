# frozen_string_literal: true

require 'delayed_job'
require File.join(Rails.root, 'app/jobs/update_package_meta_job.rb')

#
# NOTE: we do not modify, but entirely recreate the tables here, because there is
#       an issue in (older?) MySQL version which corrupt the database when modifing
#       these indexes. Since this is just indexed data based on sources we do not want
#       to go with any risk
#

class FixProductMediaUniqIndex < ActiveRecord::Migration[4.2]
  def self.up
    drop_table :product_media
    create_table :product_media do |t|
      t.references :product
      t.references :repository
      t.integer :arch_filter_id
      t.string :name
    end
    add_index :product_media, :product_id
    add_index :product_media, :arch_filter_id
    add_index :product_media, :name
    add_index :product_media, [:product_id, :repository_id, :name, :arch_filter_id], unique: true, name: 'index_unique'
    execute('alter table product_media add foreign key (product_id) references products(id)')
    execute('alter table product_media add foreign key (repository_id) references repositories(id)')
    execute('alter table product_media add foreign key (arch_filter_id) references architectures(id)')

    drop_table :product_update_repositories
    create_table :product_update_repositories do |t|
      t.references :product
      t.references :repository
      t.integer :arch_filter_id
    end
    add_index :product_update_repositories, :product_id
    add_index :product_update_repositories, :arch_filter_id
    add_index :product_update_repositories, [:product_id, :repository_id, :arch_filter_id], unique: true, name: 'index_unique'
    execute('alter table product_update_repositories add foreign key (product_id) references products(id)')
    execute('alter table product_update_repositories add foreign key (repository_id) references repositories(id)')
    execute('alter table product_update_repositories add foreign key (arch_filter_id) references architectures(id)')

    Delayed::Job.enqueue UpdatePackageMetaJob.new
  end

  def self.down
    drop_table :product_media
    create_table :product_media do |t|
      t.references :product
      t.references :repository
      t.integer :arch_filter_id
      t.string :name
    end
    add_index :product_media, :arch_filter_id
    add_index :product_media, [:product_id, :repository_id, :name], unique: true, name: 'index_unique'
    execute('alter table product_media add foreign key (product_id) references products(id)')
    execute('alter table product_media add foreign key (repository_id) references repositories(id)')
    execute('alter table product_media add foreign key (arch_filter_id) references architectures(id)')

    drop_table :product_update_repositories
    create_table :product_update_repositories do |t|
      t.references :product
      t.references :repository
      t.integer :arch_filter_id
    end
    add_index :product_update_repositories, :arch_filter_id
    add_index :product_update_repositories, [:product_id, :repository_id], unique: true, name: 'index_unique'
    execute('alter table product_update_repositories add foreign key (product_id) references products(id)')
    execute('alter table product_update_repositories add foreign key (repository_id) references repositories(id)')
    execute('alter table product_update_repositories add foreign key (arch_filter_id) references architectures(id)')

    Delayed::Job.enqueue UpdatePackageMetaJob.new
  end
end
