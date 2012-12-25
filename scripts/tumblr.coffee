# Description:
#   Allows hubot to post to tumblr
#
# Dependencies:
#   "scribe-node": ">=0.0.24"
#   "zombie-https": ">=0.0.2"
#
# Configuration:
#   HUBOT_TUMBLR_CONSUMER_KEY    - consumer key    from Tumblr
#   HUBOT_TUMBLR_CONSUMER_SECRET - consumer secret from Tumblr
#   HUBOT_TUMBLR_BLOG            - name of the blog on Tumblr
#
# Commands:
#
# Author:
#   azizshamim

api = require('scribe-node').DefaultApi10a
scribe = require('scribe-node').load(['OAuth','TwitterApi'])

# Tumblr API
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

# tumblr doesn't actually honor the oob callback
services['tumblr'] = {'provider': scribe.TumblrApi, 'key': process.env.HUBOT_TUMBLR_CONSUMER_KEY, 'secret': process.env.HUBOT_TUMBLR_CONSUMER_SECRET, 'scope': process.env.HUBOT_TUMBLR_LOG, 'callback': "#{process.env.HEROKU_URL}/oauth_callback" }

handle_authorization = (robot, msg) ->
  callback = (url) ->
    message = if url then url else "Error on retrieving url. See logs for more details."
    msg.send message
    if not robot.brain.data.oauth_user
      robot.brain.data.oauth_user = {}
    robot.brain.data.oauth_user['tumblr'] = msg.message.user.name
  new scribe.OAuth(robot.brain.data, msg.match[1].toLowerCase(), services).get_authorization_url(callback)

# manual?
handle_verification = (robot, msg) ->
  api = 'tumblr'
  callback = (response) ->
    if response
      if not robot.brain.data.oauth_user
        robot.brain.data.oauth_user = {}
      robot.brain.data.oauth_user[api] = msg.message.user.name
      message = "Verification done"
    else
      message = "Error on verification process. See logs for more details."
    msg.send message
  new scribe.OAuth(robot.brain.data, api, services).set_verification_code(msg.match[2], callback)

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
  service = new scribe.OAuth(robot.brain.data, msg.match[1].toLowerCase(), services)
  if access_token = service.get_access_token()
    callback = (response) ->
      message = if response then "Access token refreshed" else "Error on refreshing access token. See logs for more details."
      msg.send message
    service.refresh_access_token(access_token, callback)
  else
    msg.send "Access token not found"

#tumblr_link = (msg) ->
#  url = msg.match[1]
#  description = msg.match[2]
#  msg
#    .http(url)
#    .header("User-Agent: TumblrBot for Hubot (+https://github.com/github/hubot-scripts)")
#    .get() (err, res, body) ->
#      title = parse_html(body, "title")[0].children[0].data
#      unless err?
#        tumblr_post { 'type': 'link', 'state': 'published', 'url': url, 'title': title, 'description': description }
#      else
#        return undefined

#tumblr_post = (robot, params) ->
#  callback = (response) ->
#    console.log response
#  oauth = new scribe.OAuth(robot.brain.data, 'tumblr' , services)
#  if access_token = oauth.get_access_token()
#    console.log access_token
#    service = oauth.create_service
#    console.log service
#    result = service.signedPostRequest access_token, callback, "https://api.tumblr.com/v2/blog/#{process.env.HUBOT_TUMBLR_LOG}/post", params
#    return result
#
#tumblr_quote = (quote, source) ->
#  return { 'type': 'quote', 'state': 'published', 'quote': quote, 'source': source }


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
    console.log robot.brain
    console.log services['tumblr']

  robot.hear /(?:http(?:s)?:.*)(.+)?/i, (msg) ->
    # post link to tumblr (booya)
    console.log msg.match[1]

  robot.hear /['"](.*)+['"] -- (.*)$/i, (msg) ->
    response = tumblr_post robot, tumblr_quote( msg.match[1], msg.match[2] )
    console.log tumblr_quote( msg.match[1], msg.match[2] )
    console.log response

  hear_and_respond robot, 'get ([0-9a-zA-Z].*) authorization url$', (msg) ->
    handle_authorization robot, msg

#  hear_and_respond robot, 'set ([0-9a-zA-Z].*) verifier (.*)', (msg) ->
#    handle_verification robot, msg
#
#  hear_and_respond robot, 'get ([0-9a-zA-Z].*) access token$', (msg) ->
#    if token = new scribe.OAuth(robot.brain.data, msg.match[1].toLowerCase(), services).get_access_token()
#      message = "Access token: " + token.getToken()
#    else
#      message = "Access token not found"
#    msg.send message
#
#  hear_and_respond robot, 'get ([0-9a-zA-Z].*) verifier$', (msg) ->
#    if token = new scribe.OAuth(robot.brain.data, msg.match[1].toLowerCase(), services).get_verifier()
#      message = "Verifier: " + token.getValue()
#    else
#      message = "Verifier not found"
#    msg.send message
#
#  hear_and_respond robot, 'remove ([0-9a-zA-Z].*) authorization$', (msg) ->
#    api = msg.match[1].toLowerCase()
#    if robot.brain.data.oauth_user and robot.brain.data.oauth_user[api] == msg.message.user.reply_to
#      message = "Authorization removed: " + new scribe.OAuth(robot.brain.data, api, services).remove_authorization()
#    else
#      message = "Authorization can be removed by original verifier only: " + robot.brain.data.oauth_user[api]
#    msg.send message
#
#  hear_and_respond robot, 'set ([0-9a-zA-Z].*) access token (.*)', (msg) ->
#    api = msg.match[1].toLowerCase()
#    if new scribe.OAuth(robot.brain.data, api, services).set_access_token_code(msg.match[2])
#      robot.brain.data.oauth_user[api] = msg.message.user.reply_to
#      message = "Access token set"
#    else
#      message = "Error on setting access token"
#    msg.send message
