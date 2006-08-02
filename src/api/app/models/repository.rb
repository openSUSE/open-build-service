class Repository < ActiveRecord::Base
  belongs_to :db_project

  has_many :path_elements, :foreign_key => 'parent_id', :dependent => :destroy
  has_many :links, :class_name => "PathElement", :foreign_key => 'repository_id'

  has_and_belongs_to_many :architectures

  class << self
    def find_by_project_and_repo_name( project, repo )
      sql =<<-END_SQL
      SELECT r.*
      FROM repositories r
      LEFT JOIN db_projects p ON p.id = r.db_project_id
      WHERE p.name = ? AND r.name = ?
      END_SQL

      result = find_by_sql [sql, project, repo]
      result[0]
    end
  end
end
