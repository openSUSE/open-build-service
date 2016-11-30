require 'api_exception'

class Issue < ApplicationRecord
  class NotFoundError < APIException
    setup "issue_not_found", 404, "Issue not found"
  end

  has_many :package_issues, foreign_key: 'issue_id', dependent: :delete_all

  belongs_to :issue_tracker
  belongs_to :owner, class_name: "User"

  scope :stateless, -> { where(state: nil) }

  def self.find_or_create_by_name_and_tracker( name, issue_tracker_name, force_update = nil )
    find_by_name_and_tracker(name, issue_tracker_name, {
      force_update:   force_update,
      create_missing: true
    })
  end

  def self.find_by_name_and_tracker(name, issue_tracker_name, options = {})
    issue_tracker = IssueTracker.find_by_name(issue_tracker_name)
    unless issue_tracker
      raise IssueTracker::NotFoundError.new("Error: Issue Tracker '#{issue_tracker_name}' not found.")
    end

    issue = issue_tracker.issues.find_by_name(name)
    if issue.nil? && options[:create_missing]
      issue = issue_tracker.issues.create(name: name)
    end

    if options[:force_update] && issue
      issue.fetch_updates
      issue = issue_tracker.issues.find_by_name(name)
    end

    issue
  end

  def self.states
    {
      'OPEN'    => 1,
      'CLOSED'  => 2,
      'UNKNOWN' => 3
    }
  end

  def self.bugzilla_state( string )
    return 'OPEN' if %w(NEW NEEDINFO REOPENED ASSIGNED).include? string
    return 'CLOSED' if %w(RESOLVED CLOSED VERIFIED).include? string
    'UNKNOWN'
  end

  def self.valid_name?(tracker, name)
    # We only verify cve format atm. This should be done via a regexp definition in the
    # tracker definition in future
    !tracker.cve? || Regexp.new(/^\d\d\d\d-\d+$/).match(name)
  end

  after_create :fetch_issues
  def fetch_issues
    # inject update jobs after issue got created
    issue_tracker.delay(queue: 'issuetracking').fetch_issues
  end

  def fetch_updates
    # FIXME: dependency cycle, but not better solvable because multiple issues
    #        may get fetched ?
    issue_tracker.fetch_issues([self])
  end

  def label
    issue_tracker.label.gsub('@@@', name)
  end

  def webui_infos
    issue = {
      created_at: created_at,
      name:       name,
      tracker:    issue_tracker.name,
      label:      label,
      url:        url
    }

    issue[:updated_at] = updated_at if updated_at
    issue[:state]      = state if state
    issue[:summary]    = summary if summary
    # self.owner must not by used, since it is reserved by rails
    o = User.find_by_id(owner_id)
    issue[:owner] = o.login if o

    issue
  end

  def url
    issue_tracker.show_url.gsub('@@@', name)
  end

  def render_body(node, change = nil)
    p={}
    p[:change] = change if change
    node.issue(p) do |issue|
      issue.created_at(created_at)
      issue.updated_at(updated_at)   if updated_at
      issue.name(name)
      issue.tracker(issue_tracker.name)
      issue.label(label)
      issue.url(url)
      issue.state(state)             if state
      issue.summary(summary) if summary

      if owner_id
        # self.owner must not by used, since it is reserved by rails
        o = User.find owner_id
        issue.owner do |owner|
          owner.login(o.login)
          owner.email(o.email)
          owner.realname(o.realname)
        end
      end
    end
  end

  def render_axml
    builder = Nokogiri::XML::Builder.new do |node|
      render_body node
    end
    builder.to_xml indent: 2, encoding: 'UTF-8',
                               save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                             Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def to_axml(_opts = {})
    Rails.cache.fetch('issue_%d' % id) do
      render_axml
    end
  end

  # FIXME: As soon as we can convert the 'has_many :package_issues' above to use
  #        a normal CollectionProxy instead of a manually created class, get rid of this
  #        and change app/views/source/_package_issues.xml.builder to use issues directly
  def issue
    self
  end
end
