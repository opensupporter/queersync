require 'faraday/detailed_logger'

class OSDI

  attr_accessor :aep, :trace_mode, :skip_ssl_verify, :api_token

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

    return osdi
  end

  def person_signup(psh)
    hc=self.hyperclient
    psh_link=hc._links['osdi:person_signup_helper']
    response=psh_link._post psh.to_json
  end

  def record_canvass(person,canvass)
    record_canvass_link=person._links['osdi:record_canvass_helper']
    canvass_response=record_canvass_link._post canvass.to_json
  end
end