print = require './print'
makeHTTPRequest = require './make-http-request'
mergeInto = require './merge-into'
Type = require './type'

DEFAULT_TYPE_AND_ACCEPT =
  'Content-Type': 'application/vnd.api+json'
  'Accept': "application/vnd.api+json"

module.exports = class JSONAPIClient
  root: '/'
  headers: null

  types: null # Types that have been defined

  constructor: (@root, @headers = {}) ->
    @types = {}
    print.info 'Created a new JSON-API client at', @root

  request: (method, url, data, additionalHeaders) ->
    print.info 'Making a', method, 'request to', url
    headers = mergeInto {}, DEFAULT_TYPE_AND_ACCEPT, @headers, additionalHeaders
    makeHTTPRequest method, @root + url, data, headers
      .then @processResponseTo.bind this
      .catch @processErrorResponseTo.bind this

  for method in ['get', 'post', 'put', 'delete'] then do (method) =>
    @::[method] = ->
      @request method.toUpperCase(), arguments...

  processResponseTo: (request) ->
    response = try JSON.parse request.responseText
    response ?= {}
    print.log 'Processing response', response

    if 'meta' of response
      'TODO: No idea yet!'

    if 'links' of response
      for typeAndAttribute, link of response.links
        [type, attribute] = typeAndAttribute.split '.'
        if typeof link is 'string'
          href = link
        else
          {href, type: attributeType} = link

        @handleLink type, attribute, href, attributeType

    if 'linked' of response
      for type, resources of response.linked
        print.log 'Got', resources ? 1, 'linked', type, 'resources.'
        @createType type
        for resource in [].concat resources
          @types[type].addExistingResource resource

    if 'data' of response
      print.log 'Got a top-level "data" collection of', response.data.length ? 1
      primaryResults = for resource in [].concat response.data
        @createType response.type
        @types[response.type].addExistingResource resource
    else
      primaryResults = []
      for type, resources of response when type not in ['links', 'linked', 'meta', 'data']
        print.log 'Got a top-level', type, 'collection of', resources.length ? 1
        @createType type
        for resource in [].concat resources
          primaryResults.push @types[type].addExistingResource resource

    print.info 'Primary resources:', primaryResults
    Promise.all primaryResults

  handleLink: (typeName, attributeName, hrefTemplate, attributeTypeName) ->
    unless @types[typeName]?
      @createType typeName

    @types[typeName].links[attributeTypeName] ?= {}
    if hrefTemplate?
      @types[typeName].links[attributeTypeName].href = hrefTemplate
    if attributeTypeName?
      @types[typeName].links[attributeTypeName].type = attributeName

  createType: (name) ->
    @types[name] ?= new Type name, this
    @types[name]

  processErrorResponseTo: (request) ->
    Promise.reject try
      JSON.parse request.responseText
    catch
      new Error request.responseText || request.status

module.exports.util = {makeHTTPRequest}
