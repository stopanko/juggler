class AcceptPullRequestService
  def initialize(pull_request, params)
    @pull_request = pull_request
    @params = params
  end

  def call
    return if @pull_request.state == PullRequestState::ACCEPTED

    @pull_request.state = PullRequestState::ACCEPTED
    @pull_request.save
  end
end
