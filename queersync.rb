require 'hyperclient'
require './lib/osdi.rb'
require './lib/util.rb'
require 'dotenv'
require 'json'
require 'time'

Dotenv.load

config=JSON.parse(File.read(ENV['CONFIG_MAPPING_FILE']))
CONFIG=config

question_mapping=config['mapping'] || []
interval=config['interval_in_seconds']
start_date=Time.now - interval
puts "Start date #{start_date}"
start_date_string = start_date.iso8601

spoke=OSDI.new
spoke.trace_mode=config.dig('spoke','trace')
spoke.aep=config.dig('spoke','aep')
spoke.api_token=ENV['SPOKE_API_TOKEN']
spoke_aep=spoke.hyperclient

completed_people=[]

van=OSDI.new(config.dig('van'))
van.api_token=ENV['VAN_API_TOKEN']


new_answers_link=spoke_aep['osdi:answers']
unless config.dig('spoke','no_odata') == true
  new_answers_link.query_params.merge!({
    filter: "modified_date gt '#{start_date_string}'"
  })
end

new_answers=new_answers_link['osdi:answers']

new_answers.each do |a|
  person_self_link=a._links['osdi:person']._url

  next if completed_people.include?(person_self_link)
  next if (Time.parse(a.created_date)) < start_date

  completed_people << person_self_link

  osdi_person=a['osdi:person']
  person=osdi_person.to_hash

  msg=[
    person['given_name'],
    person['family_name']
  ].join(' ')

  puts "Processing #{msg}"

  psh=van.make_psh(person)
  van_person=van.person_signup(psh)
  van_person_url=van_person._links['self']._url

  puts "Matched to VAN #{van_person_url}"

  unless question_mapping.empty?
    osdi_answers=osdi_person['osdi:answers']['osdi:answers']
    canvass=Util.make_canvass(osdi_answers,question_mapping)

    canvass_response=van.record_canvass(van_person,canvass)

    if canvass_response['success']==true
      puts "SUCCESS for #{msg}"
    else
      puts "FAILED for #{msg}"
    end

  end

end
