require 'trello'
require 'qrencoder'
require "base64"
require 'sucker_punch'
require 'erb'
require 'tilt'

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

module ParamAccessor
  def initialize(params)
    @params = params
  end

  def method_missing(m)
    @params[m.to_s] || super
  end
end


class Submission
  include ParamAccessor
  def initialize(params)
    super
    SubmissionJob.perform_async(self)
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

class QRCodeBuilder
  include ParamAccessor

  def initialize(params)
    super
    @qrcode = QREncoder.encode(qr_string)
  end

  def purpose
    [
      "Пожертвование.",
      payer_name,
      birth_date,
      address+";",
      "Паспорт"+passport,
      "гр.РФ"
    ].join(' ')
  end

  def qr_string
    Tilt.new('views/qrcode_payment_string.erb').render(self)
  end

  def png
    bin = Base64.encode64(@qrcode.png(pixels_per_module: 3).to_blob)
    "<img src=\"data:image/gif;base64,#{bin}\" />"
  end
end
