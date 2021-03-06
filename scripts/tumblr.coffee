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
#   HEROKU_URL                   - url of the heroku application
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
  # TODO replace console.log with robot debugging
  # TODO text, photo, quote, link, chat, audio, video
  # DONE text, photo, quote, link,            , video
  @encode: (item) ->
    return encodeURIComponent(item)

  @hmac: (signature, key) ->
    return crypto.createHmac('sha1', key).update(signature).digest('base64')

  @param_string: (params) ->
    return ("#{key}=#{params[key]}" for key in Object.keys(params).sort() )

  # what a disaster of a function...
  @oauth_signature: (auth, data={}, secret, resource) ->
    auth_copy = {}
    ( auth_copy[key]=data[key] for key in Object.keys(data) )
    ( auth_copy[key]=auth[key] for key in Object.keys(auth) )
    api_url="http://api.tumblr.com/v2/blog/#{process.env.HUBOT_TUMBLR_LOG}/#{resource}"
    if resource == 'followers'
      api_method="GET"
    else
      api_method="POST"

    # merge data in for signature
    _signature_params = ("#{key}=#{Tumblr.encode(auth_copy[key])}" for key in Object.keys(auth_copy).sort() )
    _signature_text = "#{api_method}&#{Tumblr.encode(api_url)}&#{Tumblr.encode(_signature_params.join('&'))}"
    _signature_key = "#{process.env.HUBOT_TUMBLR_CONSUMER_SECRET}&#{secret}"
    return Tumblr.hmac(_signature_text, _signature_key)

  @oauth_headers: (robot, auth, data={}, resource) ->
    auth['oauth_signature'] = Tumblr.oauth_signature(auth, data, robot.brain.data.oauth.tumblr.access_secret, resource)
    header_base = ("#{key}=#{auth[key]}" for key in Object.keys(auth).sort() )
    return "OAuth #{header_base.join(',')}"

  # another disaster of a function
  @oauth_params: (robot) ->
    params = {}
    d = new Date
    params['oauth_consumer_key'] = process.env.HUBOT_TUMBLR_CONSUMER_KEY
    params['oauth_nonce'] = Math.floor(d.getTime()/1000)
    params['oauth_signature_method'] = 'HMAC-SHA1'
    params['oauth_timestamp'] = params['oauth_nonce']
    # replace this with a smarter retrival (error handling y'know)
    params['oauth_token']   = robot.brain.data.oauth.tumblr.access_token
    params['oauth_version'] = '1.0'
    return params

  @followers: (robot, msg) ->
    params = {}
    callback = (e,r,b) ->
      body = JSON.parse(b)
      message = "I see #{body.response.total_users} people:"
      (message = "#{message} #{person.name}" for person in body.response.users)
      msg.send message
    resource = "followers"
    api_url="http://api.tumblr.com/v2/blog/#{process.env.HUBOT_TUMBLR_LOG}/#{resource}"
    params = Tumblr.oauth_params(robot)
    headers = Tumblr.oauth_headers(robot, params, {}, resource)

    request.get {url:api_url, headers: {'authorization':headers, 'content-type':'application/x-www-form-urlencoded'}, callback }

  #disaster - fix
  #http://www.tumblr.com/docs/en/api/v2#posting
  @post: (robot, data={}, callback) ->
    # we need three specific objects (with reused information) in order to make a tumblr post
    # 1) we need a oauth header (with the signature, but not the data)
    # 2) we need the signature, which is a HMAC-SHA1 hash of the oauth header items
    # 3) we need a body which includes the oauth header items, the signature, and the post data
    api_url="http://api.tumblr.com/v2/blog/#{process.env.HUBOT_TUMBLR_LOG}/post"
    api_method='POST'
    resource = 'post'

    # create a signature with oauth parameters and post data
    params = Tumblr.oauth_params(robot,{})
    # create headers
    headers = Tumblr.oauth_headers(robot,params,data,resource)
    # create a body with oauth paramters and post data
    delete params['oauth_signature']
    params_no_sig = ("#{key}=#{Tumblr.encode(params[key])}" for key in Object.keys(params).sort() ).join('&')
    data_sorted = ("#{key}=#{Tumblr.encode(data[key])}" for key in Object.keys(data).sort() ).join('&')
    body="#{data_sorted}&#{params_no_sig}"

    request.post {url:api_url, headers: {'authorization':headers, 'content-type':'application/x-www-form-urlencoded', 'User-Agent': 'TumblrBot for Hubot (+https://github.com/github/hubot-scripts)' }, body: body}, callback

  @info: ->
    url = "https://api.tumblr.com/v2/blog/soggies.tumblr.com/info?api_key=#{process.env.HUBOT_TUMBLR_CONSUMER_KEY}"
    request.get {url: url}, (error, response, body) ->
      console.log response
      console.log body

  @definition: (robot, msg, callback) ->
    data = {}
    data.body = msg.match[0]
    data.type  = 'text'
    data.title = 'definition'
    Tumblr.post robot, data, callback

  @link: (robot, msg, callback) ->
    headers = { 'User-Agent': 'TumblrBot for Hubot (+https://github.com/github/hubot-scripts)' }
    url = msg.match[1]
    description = msg.match[2]
    callback = (e,r,b) ->
      body = JSON.parse(b)
      msg.send "posted @ http://#{process.env.HUBOT_TUMBLR_LOG}/#{body.response.id}"
    request.get { url: url, headers: headers} , (error, response, body) ->
      if ( !error and response.statusCode == 200 )
        $ = cheerio.load(body)
        content_type = response.headers['content-type'].split('/',2)
        data = {}
        data.state = 'published'
        console.log content_type
        switch content_type[0]
          when "image"
            data.type = 'photo'
            data.link = url
            data.source = url
            data.caption = description || ''
          when "video"
            data.type = 'video'
            data.caption = description || ''
            data.embed = Tumblr.embed(url)
          else
            data.type = 'link'
            data.url = url
            data.title = $('title').text()
            data.description = description || ''
        Tumblr.post robot, data, callback

  @quote: (robot, data, callback) ->
    data = { type: 'quote', quote: msg.match[1], source: msg.match[2] }
    Tumblr.post(robot, data, callback)

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

  # for debugging. turned off
  #robot.hear /debug me/, (msg) ->
  #  callback = (e,r,b) ->
  #    body = JSON.parse(b)
  #    msg.send "posted @ http://#{process.env.HUBOT_TUMBLR_LOG}/#{body.response.id}"
  #  #data = { quote: "Do or do not, there is no try", source: "Yoda" }
  #  #Tumblr.quote(robot, data, callback)
  #  #Tumblr.link(robot, data, callback)
  #  #data = { 'body': "Define: yermom is a whooah"}
  #  #Tumblr.definition(robot, data, callback)
  #  #Tumblr.link(robot, msg)

  robot.respond /who follows */, (msg) ->
    Tumblr.followers(robot, msg)

  robot.hear /(http(?:s)?:\S*)\s*(.+)?/i, (msg) ->
    Tumblr.link(robot, msg)

  robot.hear /['"](.*)+['"] -- (.+)$/i, (msg) ->
    Tumblr.quote(robot, msg)

  robot.hear /\s*defin(?:ition|e):?\s?(.+)$/i, (msg) ->
    Tumblr.definition(robot, msg)

    #  hear_and_respond robot, 'refresh me', (msg) ->
    #    handle_refresh robot, msg

  hear_and_respond robot, 'tumblr authorization url$', (msg) ->
    handle_authorization robot, msg

  hear_and_respond robot, 'tumblr verify (.*)$', (msg) ->
    handle_verification robot, msg
