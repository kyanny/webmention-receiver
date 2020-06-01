require "sinatra"
require "addressable/uri"
require "net/http"

helpers do
  # Addressable::URI -> Bool
  def validate_uri_scheme(uri)
    ['http', 'https'].include?(uri.scheme)
  end
end

get '/' do
  'aaa'
end

post '/' do
  source = params['source']
  target = params['target']
  
  # [MUST] Check if `source` and `target` parameters are given
  if !source || !target
    warn "Error: `source` and `target` parameters are required."
    halt 400, "Error: `source` and `target` parameters are required."
  end

  # 3.2.1 Request Verification
  # https://www.w3.org/TR/webmention/#request-verification

  # [MUST] Check if `source` and `target` is valid HTTP URL
  source_uri = Addressable::URI.parse(source)
  unless validate_uri_scheme(source_uri)
    warn "Error: #{source_uri} is not a valid HTTP URL."
    halt 400, "Error: #{source_uri} is not a valid HTTP URL."
  end
  target_uri = Addressable::URI.parse(target)
  unless validate_uri_scheme(target_uri)
    warn "Error: #{source_uri} is not a valid HTTP URL."
    halt 400, "Error: #{source_uri} is not a valid HTTP URL."
  end

  # [MUST] Check if `source` and `target` are different HTTP URL
  if source == target
    warn "Error: `source` and `target` must be different."
    halt 400, "Error: `source` and `target` must be different."
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
    warn "Error: `source` content must include `target` URL."
    halt 400, "Error: `source` content must include `target` URL."
  end

  # Congrats! All `MUST` verification passed.
  # TODO: store webmention data to anywhere permanent storage for future use.
  warn "Webmention from #{source} to #{target} has been successfully processed."
  "Webmention from #{source} to #{target} has been successfully processed."
end