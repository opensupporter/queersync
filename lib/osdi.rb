require 'faraday/detailed_logger'
require 'pp'

class OSDI

  attr_accessor :aep, :trace_mode, :skip_ssl_verify, :api_token, :_hc, :_mock, :add_lists, :add_tags

  def initialize(options=nil)
    options||={}
    @aep=options.dig('aep')
    @trace_mode=options.dig('trace') == true
    @api_token=options.dig('api_token')
    @_mock=options.dig('mock')
    @add_lists=options.dig('add_lists') || []
    @add_tags=options.dig('add_tags') || []

  end

  def hyperclient(raw_options={})

    if raw_options.is_a?(String)
      url=raw_options
      options={}
    else
      options=raw_options
      url=options[:url] || self.aep
    end


    token=self.api_token

    debug=options[:trace_mode] || (self.trace_mode)
    proxy=nil

    connection_options= {
      default: false
    }
    if debug || (self.skip_ssl_verify) == true

      connection_options.merge!({
                                  ssl: {verify: false}
                                })

      # proxy="http://localhost:8888"
    end

    osdi=Hyperclient.new(url) do |client|
      client.headers['OSDI-API-Token']=token
      client.connection(connection_options) do |conn|

        conn.response :detailed_logger if debug

        conn.request :hal_json
        conn.response :hal_json, content_type: /\bjson$/
        conn.proxy proxy if proxy
        conn.options[:open_timeout] = 30
        conn.options[:timeout] = 120
        #conn.use Faraday::Response::RaiseError
        conn.use FaradayMiddleware::FollowRedirects
        conn.adapter :net_http
        #conn.response :json
      end
    end
    #osdi.headers.update('Content-Type' => self.request_content_type)

    @_hc = osdi
    return osdi
  end

  def person_signup(psh)
    return mock_psh(psh) if self.mock?

    hc=@_hc || self.hyperclient
    psh_link=hc._links['osdi:person_signup_helper']
    response=psh_link._post psh.to_json
  end


  def make_psh_person(person)
    psh_person= person.slice('given_name','family_name','phone_numbers','email_addresses','postal_addresses')
    unless psh_person['email_addresses'] && CONFIG['fake_emails']==true
      psh_person['email_addresses']=[
        {
          address: [
            person['given_name'],
            '.',
            person['family_name'],
            '@',
            'fake.osdi.info'
          ].join.downcase
        }
      ]
    end
    psh_person
  end

  def make_psh(person)
    {
      'person'=> self.make_psh_person(person)
    }.tap do |p|
      p['add_lists']=self.add_lists unless self.add_lists.empty?
      p['add_tags']=self.add_tags unless self.add_tags.empty?
    end
  end

  def record_canvass(person,canvass)
    record_canvass_link=person._links['osdi:record_canvass_helper']
    canvass_response=record_canvass_link._post canvass.to_json
  end

  def mock?
    self._mock == true
  end

  def mock_psh(psh)

    pp psh if self.trace_mode
    response=psh.dig('person')
    response['_links']={
      'osdi:person' => {
        'href' => '#'
      },
      'self' => {
        'href' => '#'
      }
    }
    pp response if self.trace_mode
    Hyperclient::Resource.new(response, self.hyperclient)
  end

end