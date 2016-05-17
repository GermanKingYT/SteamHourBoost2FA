_ = require 'lodash'
chalk = require 'chalk'
Steam = require 'steam'
SteamTotp = require 'steam-totp'
Promise = require 'bluebird'
database = require('jsonfile').readFileSync 'db.json'

class SteamAccount
  constructor: ({@accountName, @password, @games, @shaSentryfile, @twoFactorCode}) ->
    @steamClient = new Steam.SteamClient
    cac: null
  login: =>
    new Promise (resolve, reject) =>
      @steamClient.on 'loggedOn', resolve
      @steamClient.on 'error', reject
      try
        @shaSentryfile = new Buffer(@shaSentryfile, 'base64')
      catch e
        @shaSentryfile = null
      if @twoFactorCode.length == 0
        @steamClient.logOn {@accountName, @password, @shaSentryfile}
      else
        @twoFactorCode = SteamTotp.generateAuthCode(@twoFactorCode)  
        console.log("Mobile Code for " + @accountName + ": " + @twoFactorCode)
        @steamClient.logOn {@accountName, @password, @twoFactorCode, @shaSentryfile}

  boost: =>
    log(chalk.green.bold('✔ ') + chalk.white("Sucessfully logged into '#{@accountName}'"))
    log(chalk.blue.bold('► ') + chalk.white('Starting to boost games ...\n'))
    @steamClient.gamesPlayed @games
    @steamClient.setPersonaState Steam.EPersonaState.Away
    setTimeout @restartLoop, 900000

  restartLoop: =>
    @steamClient.gamesPlayed([])
    setTimeout =>
      @steamClient.gamesPlayed(@games)
      setTimeout @restartLoop, 900000 # Restart games after 15min
    , 20000

_.each database, (data) ->
  acc = new SteamAccount(data)
  acc.login()
  .then ->
    acc.boost()
  .catch (e) ->
    log(chalk.bold.red("X ") + chalk.white.underline('ERROR Code: ' + e.eresult))
    if e.eresult == Steam.EResult.InvalidPassword
      log(chalk.bold.red("X ") + chalk.white("Logon failed for account '#{acc.accountName}' - invalid password\n"))
    else if e.eresult == Steam.EResult.AlreadyLoggedInElsewhere
      log(chalk.bold.red("X ") + chalk.white("Logon failed for account '#{acc.accountName}' - already logged in elsewhere\n"))
    else if e.eresult == Steam.EResult.AccountLogonDenied
      log(chalk.bold.red("X ") + chalk.white("Logon failed for account '#{acc.accountName}' - steamguard denied access\n"))

log = (message) ->
  current = new Date()
  date = current.getFullYear() + '/' + current.getMonth() + '/' + current.getDate()
  time = current.getHours() + ':' + current.getMinutes() + ':' + current.getSeconds()
  console.log chalk.bold.blue('[' + date + ' - ' + time + ']: ') + message

# Kill the script after 1 hour
setTimeout process.exit, 3600000
