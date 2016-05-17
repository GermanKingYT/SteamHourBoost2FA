jf = require 'jsonfile'
chalk = require 'chalk'
inquirer = require 'inquirer'
Steam = require 'steam'
SteamTotp = require 'steam-totp'


POSSIBLE_GAMES = [
  {name: 'CS 1.6', value: '10', checked: true}
  {name: 'CS Source', value: '240', checked: true}
  {name: 'CS GO', value: '730', checked: true}
  {name: 'Dota 2', value: '570', checked: true}
  {name: 'CS Condition Zero', value: '80', checked: true}
]

account = null

class SteamAccount
  accountName: null
  password: null
  authCode: null
  shaSentryfile: null
  twoFactorCode: null
  games: []

  constructor: (@accountName, @password, @games, @twoFactorCode) ->
    @steamClient = new Steam.SteamClient
    @steamClient.on 'loggedOn', @onLogin
    @steamClient.on 'sentry', @onSentry
    @steamClient.on 'error', @onError
    
    twoFactorCode : @twoFactorCode
  testLogin: (authCode=null) =>
    @steamClient.logOn
      accountName: @accountName,
      password: @password,
      twoFactorCode: SteamTotp.generateAuthCode(@twoFactorCode),   
      shaSentryfile: @shaSentryfile

  testLogin2: (authCode=null) =>
    @steamClient.logOn
      accountName: @accountName,
      password: @password,
      authCode: authCode,
      shaSentryfile: @shaSentryfile

  onSentry: (sentryHash) =>
    @shaSentryfile = sentryHash.toString('base64')

  onLogin: =>
    console.log(chalk.green.bold('✔ ') + chalk.white("Sucessfully logged into '#{@accountName}'"))
    setTimeout =>
      database.push {@accountName, @password, @games, @shaSentryfile, @twoFactorCode}
      jf.writeFileSync('db.json', database)
      process.exit(0)
    , 1500

  onError: (e) =>
    if e.eresult == Steam.EResult.InvalidPassword
      console.log(chalk.bold.red("X ") + chalk.white("Logon failed for account '#{@accountName}' - invalid password"))
    else if e.eresult == Steam.EResult.AlreadyLoggedInElsewhere
      console.log(chalk.bold.red("X ") + chalk.white("Logon failed for account '#{@accountName}' - already logged in elsewhere"))
    else if e.eresult == Steam.EResult.AccountLogonDenied
      query = {type: 'input', name: 'steamguard', message: 'Please enter steamguard: '}
      inquirer.prompt query, ({steamguard}) =>
        @testLogin2(steamguard)

# Load database
try
  database = jf.readFileSync('db.json')
catch e
  database = []

query = [
  {type: 'input', name: 'u_name', message: 'Enter login name: '}
  {type: 'password', name: 'u_password', message: 'Enter password: '}
  {type: 'input', name: 'u_twoFactorCode', message: 'Enter Handy "shared_secret" Key for 2FA (If needed): '}
  {type: 'checkbox', name: 'u_games', message: 'Please select games to be boosted: ', choices: POSSIBLE_GAMES}
]

inquirer.prompt query, (answers) ->
  account = new SteamAccount(answers.u_name, answers.u_password, answers.u_games, answers.u_twoFactorCode)
  unless answers.u_twoFactorCode
    account.testLogin2()
  else
    account.testLogin()
