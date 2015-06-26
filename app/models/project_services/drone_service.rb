# == Schema Information
#
# Table name: services
#
#  id                    :integer          not null, primary key
#  type                  :string(255)
#  title                 :string(255)
#  project_id            :integer
#  created_at            :datetime
#  updated_at            :datetime
#  active                :boolean          default(FALSE), not null
#  properties            :text
#  template              :boolean          default(FALSE)
#  push_events           :boolean          default(TRUE)
#  issues_events         :boolean          default(TRUE)
#  merge_requests_events :boolean          default(TRUE)
#  tag_push_events       :boolean          default(TRUE)
#  note_events           :boolean          default(TRUE), not null
#

class DroneService < CiService
  include HTTParty

  prop_accessor :drone_url, :repo, :token

  validates :drone_url, presence: true, if: :activated?
  validates :repo, presence: true, if: :activated?
  validates :token, presence: true, if: :activated?

  attr_accessor :response

  after_save :compose_service_hook, if: :activated?

  def compose_service_hook
    hook = service_hook || build_service_hook
    hook.save
  end

  def title
    'Drone'
  end

  def description
    'Open source Continuous Integration platform built on docker'
  end

  def help
    'The access token is available on your profile page at http://192.168.33.12/account/profile.'
  end

  def to_param
    'drone'
  end

  def fields
    [
        { type: 'text', name: 'drone_url', placeholder: 'http://192.168.33.12' },
        { type: 'text', name: 'repo', placeholder: 'github.com/foo/bar' },
        { type: 'text', name: 'token', placeholder: 'Drone project specific token.' }
    ]
  end

  def supported_events
    %w(push)
  end

  def build_info(sha, ref)
    url = URI.parse("#{drone_url}/api/repos/#{repo}/branches/#{ref}/commits/#{sha}?access_token=#{token}")
    raise "Request URL: #{url}"
    @response = HTTParty.get(url.to_s, verify: false)
  end

  def build_page(sha, ref)
    build_info(sha, ref) if @response.nil? || !@response.code

    url = "#{drone_url}/#{repo}"
    if @response.code != 200
      # If actual build link can't be determined, send user to build summary page.
      url
    else
      # If actual build link is available, go to build result page.
      "#{url}/#{ref}/#{sha}"
    end
  end

  def commit_status(sha, ref)
    build_info(sha, ref) if @response.nil? || !@response.code
    return :error unless @response.code == 200 || @response.code == 404

    status = if @response.code == 404
               'pending'
             else
               JSON.parse(@response.body)['status']
             end

    if 'success'.casecmp(status).zero?
      'success'
    elsif 'failed'.casecmp(status).zero?
      'failed'
    elsif 'pending'.casecmp(status).zero?
      'pending'
    elsif 'started'.casecmp(status).zero?
      'running'
    else
      :error
    end
  end

  def builds_path
    "#{drone_url}/#{repo}"
  end

  def status_img_path
    "#{drone_url}/api/badge/#{repo}/status.svg?branch=#{project.default_branch}"
  end

  def execute(data)
    return unless supported_events.include?(data[:object_kind])

    raise "Called execute"

    self.class.get("#{drone_url}/api/user?access_token=#{token}", verify: false)
  end

end
