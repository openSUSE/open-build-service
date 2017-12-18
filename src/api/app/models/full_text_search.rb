class FullTextSearch
  include ActiveModel::Serializers::JSON

  cattr_accessor :ranker, :field_weights, :per_page, :star,
                 :linked_count_weight, :activity_index_weight, :links_to_other_weight,
                 :is_devel_weight, :max_matches

  self.linked_count_weight = 100
  self.activity_index_weight = 500
  self.links_to_other_weight = -1000
  self.is_devel_weight = 1000
  self.field_weights = { name: 10, title: 2, description: 1 }
  self.ranker = :sph04
  self.per_page = 50
  self.star = false
  self.max_matches = 15000

  attr_accessor :text, :classes, :fields, :attrib_type_id, :issue_tracker_name, :issue_name
  attr_reader :result

  def initialize(attrib = {})
    if attrib
      attrib.each do |att, value|
        send(:"#{att}=", value)
      end
    end
    @result = nil
  end

  def search(options = {})
    args = { ranker:        FullTextSearch.ranker,
             star:          FullTextSearch.star,
             max_matches:   FullTextSearch.max_matches,
             order:         "adjusted_weight DESC",
             field_weights: FullTextSearch.field_weights,
             page:          options[:page],
             per_page:      options[:per_page] || FullTextSearch.per_page,
             without:       { project_id: Relationship.forbidden_project_ids } }

    args[:select] = "*, (weight() + "\
                    "#{FullTextSearch.linked_count_weight} * linked_count + "\
                    "#{FullTextSearch.links_to_other_weight} * links_to_other + "\
                    "#{FullTextSearch.is_devel_weight} * is_devel + "\
                    "#{FullTextSearch.activity_index_weight} * (activity_index * POW( 2.3276, (updated_at - #{Time.now.to_i}) / 10000000))) "\
                    "as adjusted_weight"

    issue_id = find_issue_id
    if issue_id || attrib_type_id
      args[:with] = {}
      args[:with][:issue_ids] = issue_id.to_i unless issue_id.nil?
      args[:with][:attrib_type_ids] = attrib_type_id.to_i unless attrib_type_id.nil?
    end
    if classes
      args[:classes] = classes.map { |i| i.to_s.classify.constantize }
    end

    @result = ThinkingSphinx.search search_str, args
  end

  # Needed by ActiveModel::Serializers
  def attributes
    { 'text' => nil, 'classes' => nil, 'fields' => nil, 'attrib_type_id' => nil,
      'issue_tracker_name' => nil, 'issue_name' => nil,
      'result' => nil, 'total_entries' => nil }
  end

  private

  def search_str
    if text.blank?
      nil
    elsif fields.blank?
      Riddle::Query.escape(text)
    else
      "@(#{fields.map(&:to_s).join(',')}) #{Riddle::Query.escape(text)}"
    end
  end

  def find_issue_id
    return unless issue_tracker_name && issue_name

    # compat code for handling all writings of CVE id's
    issue_name.gsub!(/^CVE-/i, '') if issue_tracker_name == "cve"
    # Return 0 if the issue does not exist in order to force an empty result
    Issue.joins(:issue_tracker).where("issue_trackers.name" => issue_tracker_name, :name => issue_name).pluck(:id).first || 0
  end
end
