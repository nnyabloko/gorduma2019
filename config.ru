require "roda"
require "addressable/template"
require 'sucker_punch'
require 'erb'
require 'tilt'
require 'trello'
require 'dotenv'
Dotenv.load
# require "bugsnag"

if ENV['ENVIRONMENT'] == 'development'
  require 'sucker_punch/testing/inline'
end

TrelloClient = Trello::Client.new(
  developer_public_key: ENV['TRELLO_PUBLIC_KEY'],
  member_token: ENV['TRELLO_MEMBER_TOKEN']
)

class SubmissionJob
  include SuckerPunch::Job
  workers 1

  def perform(s)
    s.create_card
    s.send_email
  end
end

class Submission
  def initialize(params)
    @params = params
    SubmissionJob.perform_async(self)
  end

  def method_missing(m)
    @params[m.to_s] || super
  end

  def create_card
    board = TrelloClient.find(:board, ENV['SUBMISSIONS_BOARD'])
    list = board.lists.detect {|l| l.name ==  "Новые"}
    TrelloClient.create( :card,
      {
        'idList' => list.id,
        'name' => first_name + ' ' + last_name,
        'desc' => Tilt.new('views/trello_submission_card.erb').render(self)
      }
    )
  end

  def send_email
    #Stub
  end
end

# use Bugsnag::Rack
class App < Roda
  plugin :all_verbs
  plugin :json
  route do |r|
    response['Access-Control-Allow-Origin'] = '*'
    r.options do
      response['Access-Control-Allow-Headers'] = 'content-type,x-requested-with'
      ""
    end

    r.is "v1" do
      "OK"
    end

    r.post "volunteer" do
      Submission.new(r.params)
      r.redirect "/index.html"
    end
  end
end

run App.freeze.app

# bundle exec puma -p 17888 -d config.ru
