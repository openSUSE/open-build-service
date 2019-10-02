class Staging::RequestExcluder
  include ActiveModel::Model
  attr_accessor :requests_xml_hash, :staging_workflow

  def create
    requests_to_be_excluded.map { |request| exclude_request(request) }

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

  def exclude_request(request)
    bs_request = staging_workflow.target_of_bs_requests.find_by(number: request[:number])
    return unless valid_request?(bs_request, request[:number])

    request_excluded = Staging::RequestExclusion.new(bs_request: bs_request,
                                                     number: bs_request.try(:number),
                                                     description: request[:description],
                                                     staging_workflow: staging_workflow)

    return if request_excluded.save

    errors << "Request #{request_excluded.bs_request_id}: #{request_excluded.errors.full_messages.to_sentence}."
  end

  def requests_to_be_excluded
    [requests_xml_hash[:request]].flatten
  end

  def request_numbers
    [requests_xml_hash[:number]].flatten.map(&:to_i)
  end

  def valid_request?(bs_request, request_number)
    return true if bs_request.present? && bs_request.staging_project.nil?

    errors << if bs_request.present?
                "Request #{request_number} could not be excluded because is staged in: #{bs_request.staging_project}"
              elsif BsRequest.exists?(number: request_number)
                "Request #{request_number} not found in Staging for project #{staging_workflow.project}"
              else
                "Request #{request_number} doesn't exist"
              end
    return false
  end
end
