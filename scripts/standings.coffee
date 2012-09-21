# Description:
#   Allows hubot to return baseball standings of interesting teams
#
# Dependencies:
#   "soupselect: "0.2.0"
#   "htmlparser": "1.7.6"
#   "stringformat": "0.0.5"
#
# Configuration:
#   None
#
# Commands:
#   hubot standings - baseball standings
#
# Notes:
#   Returns for Atlanta Braves, New York Mets, Washington Nationals, Chicago Cubs
#
# Author:
#   azizshamim
#
Select     	= require("soupselect").select
HtmlParser  = require "htmlparser"
$           = require "stringformat"
$.extendString("teamFormat")

watched_teams = [
  'Atlanta Braves',
  'New York Mets',
  'Washington Nationals',
  'Chicago Cubs',
]

module.exports = (robot) ->
  robot.respond /standings/i, (msg) ->
    standings(msg)

standings = (msg) ->
  msg
    .http("http://sports.yahoo.com/mlb/standings")
    .header("User-Agent: StandingsBot for HuBot (+https://github.com/github/hubot-scripts)")
    .get() (err, res, body) ->
      teams = parse_html body, '[class*="ysprow"]'
      msg.send "                       W   L   Pct   GB    L10"
      for team in teams
        do (team) -> 
          parse_team(msg, team)

parse_html = (html, selector) ->
  handler = new HtmlParser.DefaultHandler((() ->), ignoreWhitespace: true)
  parser  = new HtmlParser.Parser handler

  parser.parseComplete html
  Select handler.dom, selector

parse_team = (msg, team) ->
  a_link = Select team, 'a'
  if a_link[0]?
    name = a_link[0].children[0].data
    if name in watched_teams
      parse_team(msg, name, team)
      wins = team.children[1].children[0].data
      loss = team.children[2].children[0].data
      pct  = team.children[3].children[0].data
      gb   = team.children[4].children[0].data
      l10  = team.children[11].children[0].data
      msg.send "{0:-20} {1:3} {2:3} {3:4}  {4:5} {5:5}".teamFormat(name,wins,loss,pct,gb,l10)
