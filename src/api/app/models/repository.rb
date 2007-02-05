class Repository < ActiveRecord::Base

  belongs_to :db_project

  has_many :path_elements, :foreign_key => 'parent_id', :dependent => :destroy
  has_many :links, :class_name => "PathElement", :foreign_key => 'repository_id'
  has_many :disabled_repos, :dependent => :destroy
  has_many :download_stats

  has_and_belongs_to_many :architectures


  class << self
    def find_by_name(name)
      find :first, :conditions => ["name = BINARY ?", name]
    end

    def find_by_project_and_repo_name( project, repo )
      sql =<<-END_SQL
      SELECT r.*
      FROM repositories r
      LEFT JOIN db_projects p ON p.id = r.db_project_id
      WHERE p.name = BINARY ? AND r.name = BINARY ?
      END_SQL

      result = find_by_sql [sql, project, repo]
      result[0]
    end
  end

  #returns a list of repositories that include path_elements linking to this one
  #or empty list
  def linking_repositories
    return [] if links_count == 0
    links.map {|l| l.repository}
  end
end
