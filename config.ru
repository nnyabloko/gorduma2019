require "roda"
require "json"
require "addressable/template"
require 'dotenv'
Dotenv.load

DB = Dir.glob("data/*.json").map do |f|
    [File.basename(f, ".json").to_sym, JSON.parse(File.read(f))]
  end
  .yield_self {|a| Hash[a] }

require "./helpers.rb"

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

    r.is "map", [Integer, true] do |district_number|
      district = DB[:districts].find {|d| d['name'].to_i == district_number.to_i}
      r.redirect district['desc'].to_s[/https:\/\/yandex\.ru\/maps\/-\/.+/]
    end

    r.post "volunteer" do
      return unless r.params['__'].to_s.empty?
      Submission.new(r.params)
      r.redirect "#{ENV['HOSTNAME']}/\#volunteer"
    end

    r.post "qrcode" do
      QRCodeBuilder.new(r.params).png
    end
  end
end

run App.freeze.app

# bundle exec puma -p 17888 -d config.ru
