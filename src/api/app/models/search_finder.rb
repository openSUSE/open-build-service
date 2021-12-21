class SearchFinder
  include ActiveModel::Validations

  attr_reader :included_classes, :relation, :what, :render_all, :search_items

  validates :what, inclusion: [:package, :project, :repository, :request, :person, :channel, :channel_binary, :released_binary, :issue]

  def initialize(what:, search_items: [], render_all: false)
    @what = what
    @render_all = render_all
    @search_items = search_items
    @included_classes = []
  end

  def call
    return [] unless valid?

    case what
    when :package
      @relation = packages
    when :project
      @relation = projects
    when :repository
      @relation = repositories
    when :request
      @relation = bs_requests
    when :person
      @relation = users
    when :channel, :channel_binary
      @relation = channel_binaries
    when :released_binary
      @relation = binary_releases
    when :issue
      @relation = issues
    end
    @relation.includes(@included_classes).references(@included_classes)
  end

  private

  def packages
    @included_classes = [:project]
    Package.where(id: search_items).order('projects.name', :name)
  end

  def projects
    if render_all
      @included_classes = [:repositories]
      Project.where(id: search_items).order(:name)
    else
      Project.where(id: search_items).order(:name).select('projects.id,projects.name')
    end
  end

  def repositories
    @included_classes = [:project]
    Repository.where(id: search_items)
  end

  def bs_requests
    BsRequest.where(id: search_items).order(:id)
  end

  def users
    User.where(id: search_items).order(:login)
  end

  def channel_binaries
    ChannelBinary.where(id: search_items)
  end

  def binary_releases
    BinaryRelease.where(id: search_items)
  end

  def issues
    @included_classes = [:issue_tracker]
    Issue.where(id: search_items)
  end
end
