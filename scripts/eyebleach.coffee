# Description:
#   Allows hubot to return an eyebleach image to bleach your brain
#
# Dependencies:
#
# Configuration:
#   None
#
# Commands:
#   hubot eyebleach
#
# Notes:
#
# Author:
#   azizshamim

module.exports = (robot) ->
  robot.respond /((bleach my eyes)|eyebleach)/i, (msg) ->
    eyebleach(msg)

pad = (n) ->
  if (n < 10)
    return "00" + n;
  if (n < 100)
    return "0" + n;
  return n;

eyebleach = (msg) ->
  num = Math.floor Math.random() * 102
  msg.send "http://www.eyebleach.com/eyebleach/eyebleach_"+pad(num)+".jpg"
