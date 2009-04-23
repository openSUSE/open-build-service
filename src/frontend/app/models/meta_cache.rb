class MetaCache < ActiveRecord::Base
  set_table_name 'meta_cache'
  belongs_to :cachable, :polymorphic => :true
end
