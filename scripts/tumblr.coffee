# Description:
#   Allows hubot to post to tumblr
#
# Dependencies:
#   "scribe-node": ">=0.0.24"
#   "cheerio": "0.7.0"
#   "request": "2.12.0"
#
# Configuration:
#   HUBOT_TUMBLR_CONSUMER_KEY    - consumer key    from Tumblr
#   HUBOT_TUMBLR_CONSUMER_SECRET - consumer secret from Tumblr
#   HUBOT_TUMBLR_LOG             - name of the blog on Tumblr
#   HUBOT_TUMBLR_CALLBACK_URL    - name of callback url (or HUBOT_URL on heroku)
#
# Commands:
#   tumblr authorization url - get the authorization url for tumblr, log into tumblr when asked and as long as there's a callback url...
#   tumblr verify <verification_code> - manually verify the auth request, using verification_key obtained from tumblr redirect failure url
#
# Author:
#   azizshamim

api = require('scribe-node').DefaultApi10a
scribe = require('scribe-node').load(['OAuth','TwitterApi'])
cheerio = require('cheerio')
request = require('request')
crypto  = require('crypto')

# Tumblr OAuth API
class scribe.TumblrApi extends api
  constructor: ->
    @REQUEST_TOKEN_URL = "http://www.tumblr.com/oauth/request_token"
    @ACCESS_TOKEN_URL  = "http://www.tumblr.com/oauth/access_token"
    @AUTHORIZE_URL     = "http://www.tumblr.com/oauth/authorize?oauth_token="

  getAccessTokenEndpoint: ->
    return @ACCESS_TOKEN_URL

  getRequestTokenEndpoint: ->
    return @REQUEST_TOKEN_URL

  getAccessTokenVerb: ->
    return @POST

  getRequestTokenVerb: ->
    return @POST

  getRequestVerb: ->
    return @POST

  getAuthorizationUrl: (request_token) ->
    return @AUTHORIZE_URL + request_token.getToken()

`function getOAuthVerifier(path) {
  var vars = {};
  var parts = path.replace(/[?&]+([^=&]+)=([^&]*)/gi, function(m,key,value) {
    vars[key] = value;
  });
  return vars['oauth_verifier'];
}`

services = {}

callback = if process.env.HUBOT_TUMBLR_CALLBACK_URL then process.env.HUBOT_TUMBLR_CALLBACK_URL else "#{process.env.HEROKU_URL}/oauth_callback"

callback_url = ->
  cbu = if process.env.HUBOT_TUMBLR_CALLBACK_URL then process.env.HUBOT_TUMBLR_CALLBACK_URL else "#{process.env.HEROKU_URL}/oauth_callback"
  return encodeURIComponent(cbu)

# tumblr doesn't actually honor the oob callback
services['tumblr'] = {
  'provider': scribe.TumblrApi,
  'key': process.env.HUBOT_TUMBLR_CONSUMER_KEY,
  'secret': process.env.HUBOT_TUMBLR_CONSUMER_SECRET,
  'scope': process.env.HUBOT_TUMBLR_LOG,
  'callback': callback
}

handle_authorization = (robot, msg) ->
  api = 'tumblr'
  callback = (url) ->
    message = if url then url+"&oauth_callback=#{callback_url()}" else "Error on retrieving url. See logs for more details."
    msg.send message
    if not robot.brain.data.oauth_user
      robot.brain.data.oauth_user = {}
    robot.brain.data.oauth_user[api] = msg.message.user.name
  new scribe.OAuth(robot.brain.data, api, services).get_authorization_url(callback)

handle_callback_verification = (robot, verification) ->
  api = 'tumblr'
  callback = (response) ->
    if response
      if not robot.brain.data.oauth_user
        robot.brain.data.oauth_user = {}
      message = "Verification done"
    else
      message = "Error on verification process. See logs for more details."
  new scribe.OAuth(robot.brain.data, api, services).set_verification_code(verification, callback)

handle_refresh = (robot, msg) ->
  api = 'tumblr'
  service = new scribe.OAuth(robot.brain.data, api, services)
  if access_token = service.get_access_token()
    callback = (response) ->
      message = if response then "Access token refreshed" else "Error on refreshing access token. See logs for more details."
      msg.send message
    service.refresh_access_token(access_token, callback)
  else
    msg.send "Access token not found"

## manual
handle_verification = (robot, msg) ->
  api = 'tumblr'
  verification_code = msg.match[1]
  callback = (response) ->
    if response
      if not robot.brain.data.oauth_user
        robot.brain.data.oauth_user = {}
      robot.brain.data.oauth_user[api] = msg.message.user.name
      message = "Verification done"
    else
      message = "Error on verification process. See logs for more details."
    msg.send message
  new scribe.OAuth(robot.brain.data, api, services).set_verification_code(verification_code, callback)

# tumblr
class Tumblr
  @encode: (item) ->
    return encodeURIComponent(item)

  @hmac: (signature, key) ->
    return crypto.createHmac('sha1', key).update(signature).digest('base64')

  @oauth_signature: (oauth_params, secret) ->
    api_url="http://api.tumblr.com/v2/blog/soggies.tumblr.com/followers"
    api_method="GET"

    _signature_params = ("#{key}=#{oauth_params[key]}" for key in Object.keys(oauth_params).sort() )
    _signature_params_join = _signature_params.join('&')
    _signature_text = "#{api_method}&#{Tumblr.encode(api_url)}&#{Tumblr.encode(_signature_params_join)}"
    _signature_key = "#{process.env.HUBOT_TUMBLR_CONSUMER_SECRET}&#{secret}"
    console.log "OAuth params: #{oauth_params}"
    console.log "Signature params: #{_signature_params}"
    console.log "Signature joined: #{_signature_params_join}"
    console.log "Signature text: #{_signature_text}"
    console.log "Signature Key: #{_signature_key}"
    return Tumblr.hmac(_signature_text, _signature_key)

  @followers: (robot, params,callback) ->
    api_url="http://api.tumblr.com/v2/blog/soggies.tumblr.com/followers"
    oauth_params = {}

    d = new Date
    oauth_params['oauth_consumer_key'] = process.env.HUBOT_TUMBLR_CONSUMER_KEY
    oauth_params['oauth_nonce'] = Math.floor(d.getTime()/1000)
    oauth_params['oauth_signature_method'] = 'HMAC-SHA1'
    oauth_params['oauth_timestamp'] = oauth_params['oauth_nonce']
    # replace this with a smarter retrival (error handling y'know)
    oauth_params['oauth_token']   = robot.brain.data.oauth.tumblr.access_token
    oauth_params['oauth_version'] = '1.0'

    oauth_headers = oauth_params
    oauth_headers['oauth_signature'] = Tumblr.oauth_signature(oauth_params, robot.brain.data.oauth.tumblr.access_secret)

    _header_base = ("#{key}=#{oauth_headers[key]}" for key in Object.keys(oauth_headers).sort() )
    header_base = _header_base.join(',')
    headers="OAuth #{header_base}"
    console.log headers
    request.get {url:api_url, headers: {'authorization':headers, 'content-type':'application/x-www-form-urlencoded'}, callback }

  @post: (robot, params, callback) ->
    # we need three specific objects (with reused information) in order to make a tumblr post
    # 1) we need a oauth header
    #    "Authorization: OAuth oauth_consumer_key=$oauth_consumer_key, oauth_token=$oauth_token, oauth_signature_method=$oauth_signature_method, oauth_signature=$oauth_signature, oauth_timestamp=$oauth_timestamp, oauth_nonce=$oauth_nonce, oauth_version=$oauth_version"
    # 2) we need the signature, which is a HMAC-SHA1 hash of the oauth header items
    # 3) we need a body which includes the oauth header items, the signature, and the post data
    api_url="http://api.tumblr.com/v2/blog/#{process.env.HUBOT_TUMBLR_LOG}/post"
    api_method="POST"

    oauth_params = {}

    d = new Date
    oauth_params['oauth_consumer_key'] = process.env.HUBOT_TUMBLR_CONSUMER_KEY
    oauth_params['oauth_nonce'] = Math.floor(d.getTime()/1000)
    oauth_params['oauth_signature_method'] = 'HMAC-SHA1'
    oauth_params['oauth_timestamp'] = oauth_params['oauth_nonce']
    # replace this with a smarter retrival (error handling y'know)
    oauth_params['oauth_token']   = robot.brain.data.oauth.tumblr.access_token
    oauth_params['oauth_version'] = '1.0'

    #signature_base="oauth_consumer_key=#{oauth_consumer_key}&oauth_nonce=#{oauth_nonce}&oauth_signature_method=#{oauth_signature_method}&oauth_timestamp=#{oauth_timestamp}&oauth_token=#{oauth_token}&oauth_version=#{oauth_version}"
    # list comprehension method
    _signature_base = ("#{key}=#{encodeURIComponent(oauth_params[key])}" for key in Object.keys(oauth_params).sort() )
    signature_base = _signature_base.join('&')

    _signature_content = ("#{key}=#{encodeURIComponent(params[key])}" for key in Object.keys(params).sort() )
    signature_content = _signature_content.join('&')

    signature_params="#{signature_base}&#{signature_content}"
    signature_text="#{api_method}&#{encodeURIComponent(api_url)}&#{encodeURIComponent(signature_params)}"
    # more safe retrieval
    signature_key="#{process.env.HUBOT_TUMBLR_CONSUMER_SECRET}&#{robot.brain.data.oauth.tumblr.access_secret}"

    oauth_params['oauth_signature'] = crypto.createHmac('sha1', signature_key).update(signature_text).digest('base64')
    console.log "Signature: #{oauth_params['oauth_signature']}"

    _header_base = ("#{key}=#{oauth_params[key]}" for key in Object.keys(oauth_params).sort() )
    header_base = _signature_base.join(',')
    console.log header_base

    body="#{signature_content}&#{signature_base}"

  #  if callback
    request.post {url:api_url, headers: { 'authorization': header_base}, form:body}, (e,r,body) ->
      console.log e
      console.log r
      console.log b
  #$(curl -X POST ${api_url} --data "$body" -H "authorization: $oauth_headers" -H "content-type: application/x-www-form-urlencoded" -qs)
  #    callback(message)

  @info: ->
    url = "https://api.tumblr.com/v2/blog/soggies.tumblr.com/info?api_key=#{process.env.HUBOT_TUMBLR_CONSUMER_KEY}"
    request.get {url: url}, (error, response, body) ->
      console.log response
      console.log body

# tumblr post prep
  @link: (robot, msg) ->
    url = msg.match[1]
    description = msg.match[2]
    headers = { 'User-Agent': 'TumblrBot for Hubot (+https://github.com/github/hubot-scripts)' }
    request.get {url: url, headers: headers }, (error, response, body) ->
      if ( !error and response.statusCode == 200 )
        $ = cheerio.load(body)
        title = $('title').text()
        console.log title
        Tumblr.post(robot, { 'type': 'link', 'state': 'published', 'url': url, 'title': title, 'description': description })

  @quote: (robot, quote, source) ->
    params =  { 'type': 'quote', 'state': 'published', 'quote': quote, 'source': source }
    Tumblr.post(robot, params)

# small factory to support both gtalk and other adapters by hearing all lines or those called by bot name only

hear_and_respond = (robot, regex, callback) ->
  robot.hear eval('/^'+regex+'/i'), callback
  robot.respond eval('/'+regex+'/i'), callback

module.exports = (robot) ->
  robot.router.get "/oauth_callback", (req, res) ->
    verifier = getOAuthVerifier(req['_parsedUrl']['query'])
    handle_callback_verification robot, verifier
    robot.brain.save()
    res.end "You have been verified - go ask crunchy"

  robot.hear /debug me/, (msg) ->
    callback = (e,r,b) ->
      console.log "and then..."
      console.log b
    Tumblr.followers(robot,msg,callback)

  robot.hear /(http(?:s)?:\S*)\s+(.+)?/i, (msg) ->
    Tumblr.link(robot, msg)

  robot.hear /['"](.*)+['"] -- (.*)$/i, (msg) ->
    Tumblr.quote(robot, msg.match[1], msg.match[2])

    #  hear_and_respond robot, 'refresh me', (msg) ->
    #    handle_refresh robot, msg

  hear_and_respond robot, 'tumblr authorization url$', (msg) ->
    handle_authorization robot, msg

  hear_and_respond robot, 'tumblr verify (.*)$', (msg) ->
    handle_verification robot, msg
