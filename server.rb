require "sinatra"
require "addressable/uri"
require "net/http"
require "json"

configure do
  DB = Hash.new{ |h,k| h[k] = [] }
end

helpers do
  # Addressable::URI -> Bool
  def validate_uri_scheme(uri)
    ['http', 'https'].include?(uri.scheme)
  end

  def halt_with_message(message, status_code = 400)
    logger.info message
    halt status_code, message
  end

  def success_with_message(message, status_code = 200)
    logger.info message
    status status_code
    message
  end

  def insert_to_store(source, target)
    # TODO: support poermanent storage if available
    DB[target] << source
  end

  def select_from_store(target)
    DB[target]
  end
end

get '/' do
  if params['url']
    # URL is given. Return stored webmentions.
    content_type :json
    select_from_store(params['url']).to_json
  else
    erb :index
  end
end

post '/' do
  source = params['source']
  target = params['target']
  
  # [MUST] Check if `source` and `target` parameters are given
  unless source
    halt_with_message "Error: `source` parameter is required."
  end
  unless target
    halt_with_message "Error: `target` parameter is required."
  end

  # 3.2.1 Request Verification
  # https://www.w3.org/TR/webmention/#request-verification

  # [MUST] Check if `source` and `target` is valid HTTP URL
  source_uri = Addressable::URI.parse(source)
  unless validate_uri_scheme(source_uri)
    halt_with_message "Error: `source` #{source_uri} is not a valid HTTP URL."
  end
  target_uri = Addressable::URI.parse(target)
  unless validate_uri_scheme(target_uri)
    halt_with_message "Error: `target` #{target_uri} is not a valid HTTP URL."
  end

  # [MUST] Check if `source` and `target` are different HTTP URL
  if source == target
    halt_with_message "Error: `source` and `target` must be different."
  end

  # 3.2.2 Webmention Verification
  # https://www.w3.org/TR/webmention/#h-webmention-verification
  
  # Get `source` content
  url = source
  res = nil
  loop do
    res = Net::HTTP.get_response(Addressable::URI.parse(url))
    break unless res.is_a?(Net::HTTPRedirection)
    url = res['location']
  end

  # Check if `source` content includes `target` URL
  unless res.body.include?(target)
    halt_with_message "Error: `source` content must include `target` URL."
  end

  # Congrats! All `MUST` verification passed.
  # TODO: store webmention data to anywhere permanent storage for future use.
  insert_to_store(source, target)
  success_with_message "Webmention from #{source} to #{target} has been successfully processed."
end