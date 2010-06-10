class PublishFlag < Flag
  belongs_to :db_project
  belongs_to :db_package
  belongs_to :architecture
end
