# typed: true
class Staging::RequestExcluder
  include ActiveModel::Model
  attr_accessor :requests_xml_hash, :staging_workflow

  def create
    requests_to_be_excluded.map do |request|
      bs_request = staging_workflow.unassigned_requests.find_by_number(request[:number])
      request_excluded = Staging::RequestExclusion.new(bs_request: bs_request,
                                                       number: bs_request.try(:number),
                                                       description: request[:description],
                                                       staging_workflow: staging_workflow)

      errors << "Request #{request_excluded.bs_request_id}: #{request_excluded.errors.full_messages.to_sentence}." unless request_excluded.save
    end

    self
  end

  def destroy
    request_exclusions = staging_workflow.request_exclusions.where(number: request_numbers).destroy_all
    not_found_requests = request_numbers - request_exclusions.try(:pluck, :number)

    errors << "Requests with number #{not_found_requests.to_sentence} couldn't be unexcluded." if not_found_requests.present?
    self
  end

  def errors
    @errors ||= []
  end

  def valid?
    errors.empty?
  end

  private

  def requests_to_be_excluded
    [requests_xml_hash[:request]].flatten
  end

  def request_numbers
    [requests_xml_hash[:number]].flatten.map(&:to_i)
  end
end
