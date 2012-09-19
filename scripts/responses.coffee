# Description:
#   Responses to give crunchy character
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   None
#
#

badgers = [
  "badger badger badger",
  "badger badger badger",
  "badger badger badger",
  "mushroom, mushroom",
  "mushroom, mushroom",
  "SNAAAAKE OOOOH IT'S A SNAAAAAAKE!",
]

module.exports = (robot) ->
  robot.respond /global business excellence/i, (msg) ->
    msg.send "UNISON!"

  robot.respond /unison/i, (msg) ->
    msg.send "The Way To Global Business Excellence!"

  robot.respond /badger/i, (msg) ->
    msg.send msg.random badgers


