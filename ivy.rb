require 'rack'
require 'nokogiri'
require 'open-uri'
require 'json'

def scrape(month, day)
  return "Invalid date!" unless date_valid?(month, day)
  results = { 'people' => [] }
  doc = Nokogiri::HTML(open("http://www.imdb.com/search/name?birth_monthday=#{month}-#{day}"))
  actors = doc.css('.lister-item')
  actors.each do |actor|
    results['people'].push(build_actor(actor)) if is_actor?(actor)
    break if results['people'].length >= 10
  end
  results
end

def date_valid?(month, day)
  days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  (month >= 0 && month <= 12) && (day >= 0 && day <= days[month - 1])
end

def is_actor?(actor)
  job = actor.css('p.text-muted > text()').text.strip
  job == "Actress" || job == "Actor"
end

def build_actor(actor)
  actor_obj = {}
  actor_obj['name'] = actor.css('.lister-item-header a').text.strip
  actor_obj['photoUrl'] = actor.css('.lister-item-image img')[0]['src']
  actor_obj['profileUrl'] = 'http://www.imdb.com' + actor.css('.lister-item-header a')[0]['href']
  actor_obj['mostKnownWork'] = build_most_known_work(actor)
  actor_obj
end

def build_most_known_work(actor)
  most_known_work = {}
  work_url = 'http://www.imdb.com' + actor.css('.text-muted a')[0]['href']
  work_page = Nokogiri::HTML(open(work_url))
  most_known_work['title'] = work_page.css('.title_wrapper h1 > text()').text.strip[0...-1]
  most_known_work['url'] = work_url
  most_known_work['rating'] = work_page.css('span[itemprop="ratingValue"]').text.strip
  most_known_work['director'] = work_page.css('span[itemprop="director"]').text.strip
  most_known_work['director'] = 'Multiple' if most_known_work['director'] == ''
  most_known_work
end

if __FILE__ == $PROGRAM_NAME
  app = Proc.new do |env|
    req = Rack::Request.new(env)
    res = Rack::Response.new
    res.write(scrape(req.params['month'].to_i, req.params['day'].to_i).to_json)
    res.finish
  end

  Rack::Server.start(
    app: app,
    Port: 3000
  )
end
