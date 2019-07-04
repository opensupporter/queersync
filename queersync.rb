require 'hyperclient'
require './lib/osdi.rb'
require './lib/util.rb'
require 'dotenv'
require 'json'
require 'time'

Dotenv.load

config=JSON.parse(File.read(ENV['CONFIG_MAPPING_FILE']))
question_mapping=config['mapping']
interval=config['interval_in_seconds']
start_date=Time.now - interval
puts "Start date #{start_date}"

spoke=OSDI.new
spoke.trace_mode=config.dig('spoke','trace')
spoke.aep=config.dig('spoke','aep')
spoke.api_token=ENV['SPOKE_API_TOKEN']
spoke_aep=spoke.hyperclient

completed_people=[]

van=OSDI.new
van.trace_mode=config.dig('van','trace')
van.aep=config.dig('van','aep')
van.api_token=ENV['VAN_API_TOKEN']



new_answers=spoke_aep['osdi:answers']['osdi:answers']

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

  psh=Util.make_psh(person)
  van_person=van.person_signup(psh)
  van_person_url=van_person._links['self']._url

  puts "Matched to VAN #{van_person_url}"

  osdi_answers=osdi_person['osdi:answers']['osdi:answers']
  canvass=Util.make_canvass(osdi_answers,question_mapping)

  canvass_response=van.record_canvass(van_person,canvass)

  if canvass_response['success']==true
    puts "SUCCESS for #{msg}"
  else
    puts "FAILED for #{msg}"
  end

end
