class PublishFlag < Flag
	belongs_to :db_project
	belongs_to :db_package
	belongs_to :architecture	
#	acts_as_list :scope => 'project_id = #{project_id || "NULL"} AND package_id = #{package_id || "NULL"}'

	protected

	private
	
end