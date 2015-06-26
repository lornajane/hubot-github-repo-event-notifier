#! /usr/bin/env coffee

enableColors = process.env['HUBOT_GITHUB_EVENT_NOTIFIER_IRC_COLORS']

if enableColors?
  IrcColors = require "irc-colors"

unique = (array) ->
  output = {}
  output[array[key]] = array[key] for key in [0...array.length]
  value for key, value of output

extractMentionsFromBody = (body) ->
  mentioned = body.match(/(^|\s)(@[\w\-\/]+)/g)

  if mentioned?
    mentioned = mentioned.filter (nick) ->
      slashes = nick.match(/\//g)
      slashes is null or slashes.length < 2

    mentioned = mentioned.map (nick) -> nick.trim()
    mentioned = unique mentioned

    "\nMentioned: #{mentioned.join(", ")}"
  else
    ""

formatUser = (message) ->
  if IrcColors?
    "#{IrcColors.pink(message)}"
  else
    "#{message}"

formatLink = (message) ->
  if IrcColors?
    "#{IrcColors.blue(message)}"
  else
    "#{message}"

formatProse = (message) ->
  if IrcColors?
    # handle newlines
    lines = message.split(/\r\n|\r|\n/g)
    result = ""
    for line in lines
      if line.length
        result = result + "#{IrcColors.gray(line)}" + "\n"

    result.trim()
  else
    "#{message}"

buildNewIssueOrPRMessage = (data, eventType, callback) ->
  pr_or_issue = data[eventType]
  if data.action == 'opened'
    mentioned_line = ''
    if pr_or_issue.body?
      mentioned_line = extractMentionsFromBody(pr_or_issue.body)
    callback "New #{eventType.replace('_', ' ')} \"#{pr_or_issue.title}\" by #{formatUser(pr_or_issue.user.login)}: #{formatLink(pr_or_issue.html_url)}#{mentioned_line}"
  else if data.action == 'reopened'
    callback "Reopened #{eventType.replace('_', ' ')} \"#{pr_or_issue.title}\" by #{formatUser(pr_or_issue.user.login)}: #{formatLink(pr_or_issue.html_url)}"
  else if data.action == 'closed'
    if pr_or_issue.merged
      callback "Merged: #{eventType.replace('_', ' ')} \"#{pr_or_issue.title}\" by #{formatUser(pr_or_issue.user.login)} (#{formatLink(pr_or_issue.html_url)})"
    else
      callback "#{formatUser(data.sender.login)} closed #{eventType.replace('_', ' ')} \"#{pr_or_issue.title}\" without merge (#{formatLink(pr_or_issue.html_url)})"
  else if data.action == 'synchronize'
    callback "New commits on #{eventType.replace('_', ' ')} \"#{pr_or_issue.title}\" (#{formatLink(pr_or_issue.html_url)})"


module.exports =
  issues: (data, callback) ->
    buildNewIssueOrPRMessage(data, 'issue', callback)

  pull_request: (data, callback) ->
    buildNewIssueOrPRMessage(data, 'pull_request', callback)

  page_build: (data, callback) ->
    build = data.build
    if build?
      if build.status is "built"
        callback "#{build.pusher.login} built #{data.repository.full_name} pages in #{build.duration}ms."
      if build.error.message?
        callback "Page build for #{data.repository.full_name} errored: #{build.error.message}."

# comments on pull requests are also considered issue comments
  issue_comment: (data, callback) ->
    callback "New comment on \"#{data.issue.title}\" (#{formatLink(data.comment.html_url)}) by #{formatUser(data.comment.user.login)}: \"#{formatProse(data.comment.body)}\""

  push: (data, callback) ->
    if (data.ref == 'refs/heads/master' || data.ref == 'refs/heads/gh-pages')
      commit_count = data.commits.length
      callback "#{formatUser(data.sender.login)} pushed #{commit_count} commits to #{data.repository.name}"
    else
      console.log("Notifications only on master and gh-pages branches")

  pull_request_review_comment: (data, callback) ->
    callback "#{formatUser(data.comment.user.login)} commented on pull request \"#{data.pull_request.title}\" (#{formatLink(data.pull_request.html_url)})"

  gollum: (data, callback) ->
    callback "#{formatUser(data.sender.login)} updated the wiki"
