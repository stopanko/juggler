class CreatePullRequestFromPayloadService

  def initialize(payload, opts={})
    @payload = payload
  end

  def call
    if @payload['pull_request'].present?
      @pull_request = PullRequest.find_by_github_id(@payload['pull_request']['id'])
      if @pull_request.nil?
        PullRequest.create(pr_params(@payload))
      else
        @pull_request.update_attribute :state, 'pending'
      end
    end
    send_slack_info_message
    send_email_to_reviewer
  end

  private

  def pr_params(payload)
    pr_hash = {}
    pr_hash[:state] = 'pending'
    pr_hash[:github_id] = payload['pull_request']['id']
    pr_hash[:opened_at] = payload['pull_request']['created_at']
    pr_hash[:title] = payload['pull_request']['title']
    pr_hash[:body] = payload['pull_request']['body']
    pr_hash[:repository_id] = Repository.find_by_github_id(payload['repository']['id']).id
    return pr_hash
  end

  def send_slack_info_message
    slack = SlackClient.new()
    url = Rails.application.routes.url_helpers.pull_request_url(@pull_request, host: ENV["ACTION_MAILER_HOST"])
    if @pull_request.reviewer
      slack.send_message("[PR](#{url}) back after correction", @pull_request.reviewer.slack_channel)
      ReminderWorker.perform_at(ENV["REMAIND_AFTER_HOURS"].to_i.hours.from_now, @pull_request.id)
    else
      slack.send_message("New [PR](#{url}) to review")
    end
  end

  def send_email_to_reviewer
    return unless @pull_request.reviewer
    NotificationMailer.back_to_review(@pull_request).deliver_now
  end
end