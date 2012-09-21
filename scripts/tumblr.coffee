# Description:
#   Allows hubot to post to tumblr
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_OAUTH_CONSUMER_KEY    - consumer key    from Tumblr
#   HUBOT_OAUTH_CONSUMER_SECRET - consumer secret from Tumblr
#
# Commands:
#   None
#
# Author:
#   azizshamim

## Request-token URL: ## POST http://www.tumblr.com/oauth/request_token
## Authorize URL:     ##      http://www.tumblr.com/oauth/authorize
## Access-token URL:  ## POST http://www.tumblr.com/oauth/access_token


##OAUTH_CONSUMER_KEY=dHK0oxSvFZHCQcSA2Hc1XuGE6r4emj4JLdMSfS2tFdHIyrsH1q
##OAUTH_CONSUMER_SECRET=oGvceIXTy6A7uzwIsX9eqWgf6JgK4nNf8ivuMOK8v8s2LfFksW
##OAUTH_TOKEN=
##OAUTH_TOKEN_SECRET=
#

tumblelog_domain = "soggies.tumblr.com"

module.exports = (robot) ->
  options = {
    request_url :     "http://www.tumblr.com/oauth/request_token",
    authorize_url:    "http://www.tumblr.com/oauth/authorize",
    access_url:       "http://www.tumblr.com/oauth/access_token",
    consumer_key:     process.env.HUBOT_OAUTH_CONSUMER_KEY,
    consumer_secret:  process.env.HUBOT_OAUTH_CONSUMER_SECRET,
  }

  robot.respond /.*(http(s)?:.*).*/i, (msg) ->
    key = tumblr_auth msg
