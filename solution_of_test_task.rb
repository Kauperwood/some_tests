require 'mechanize'
require 'oj'
require 'redis'

class Item
  attr_accessor :title, :reviews, :json
  def initialize(title, reviews, json)
    @title = title
    @reviews = reviews
    @json = json
  end

  def inspect
    "title: #{title}, reviews: #{reviews}, json: #{json}"
  end

  def serialize
    Oj.dump({title: title, reviews: reviews, json: json})
  end
end

redis = Redis.current

agent = Mechanize.new
page_number = redis.get("rozetka:smartfon:page_number").to_i + 1
page = agent.get("https://rozetka.com.ua/mobile-phones/c80003/goods_block/page=#{page_number};preset=smartfon/")

redis.del "rozetka:smartfon" if page_number == 1

page.parser.css('.g-i-tile.g-i-tile-catalog').each do |item_el|
  a_el = item_el.at('.g-i-tile-i-title a') || next
  script_el = item_el.at('script') || next
  if (m = script_el.text.match(/var pricerawjson = '([^']+)';/))
    json = Oj.load(CGI.unescape(m[1]), {})
    review_el = item_el.at('.g-rating-reviews')
    item = Item.new(a_el.text.strip, review_el.text.gsub(/\D/, '').to_i, json)
    redis.hset("rozetka:smartfon", item.title, item.serialize)
  end
end

redis.setex("rozetka:smartfon:page_number", 300, page_number)

puts redis.hgetall("rozetka:smartfon")
puts "page_number: #{page_number}"