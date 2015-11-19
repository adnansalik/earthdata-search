#= require models/data/granules
#= require models/data/service_options

ns = @edsc.models.data

ns.Collection = do (ko
                 DetailsModel = @edsc.models.DetailsModel
                 scalerUrl = @edsc.config.browseScalerUrl
                 ServiceOptionsModel = ns.ServiceOptions
                 toParam=jQuery.param
                 extend=jQuery.extend
                 ajax = @edsc.util.xhr.ajax
                 dateUtil = @edsc.util.date
                 config = @edsc.config
                 ) ->

  openSearchKeyToEndpoint =
    cwic: (collection) ->
      short_name = collection.json.short_name
      "http://cwic.wgiss.ceos.org/opensearch/granules.atom?datasetId=#{short_name}&clientId=#{config.cmrClientId}"

  collections = ko.observableArray()

  randomKey = Math.random()

  register = (collection) ->
    collection.reference()
    collections.push(collection)
    collection

  class Collection extends DetailsModel
    @awaitDatasources: (collections, callback) ->
      calls = collections.length
      aggregation = ->
        calls--
        callback(collections) if calls == 0

      for collection in collections
        collection.granuleDatasourceAsync(aggregation)


    @findOrCreate: (jsonData, query) ->
      id = jsonData.id
      featured = jsonData.featured
      for collection in collections()
        if collection.id == id
          if (jsonData.short_name? && !collection.hasAtomData()) || collection.featured != featured || jsonData.granule_count != collection.granule_count
            collection.fromJson(jsonData)
          return collection.reference()
      register(new Collection(jsonData, query, randomKey))

    @visible: ko.computed
      read: -> collection for collection in collections() when collection.visible()

    constructor: (jsonData, @query, inKey) ->
      throw "Collections should not be constructed directly" unless inKey == randomKey
      @granuleCount = ko.observable(0)

      @hasAtomData = ko.observable(false)

      @details = @asyncComputed({}, 100, @_computeCollectionDetails, this)
      @detailsLoaded = ko.observable(false)

      @spatial = @computed(@_computeSpatial, this, deferEvaluation: true)
      @timeRange = @computed(@_computeTimeRange, this, deferEvaluation: true)
      @granuleDescription = @computed(@_computeGranuleDescription, this, deferEvaluation: true)
      @granuleDatasource = ko.observable(null)
      @osddUrl = @computed(@_computeOsddUrl, this, deferEvaluation: true)

      @visible = ko.observable(false)

      @fromJson(jsonData)

      @spatial_constraint = @computed =>
        if @points?
          'point:' + @points[0].split(/\s+/).reverse().join(',')
        else
          null

      @echoGranulesUrl = @computed
        read: =>
          if @granuleDatasourceName() == 'cmr' && @granuleDatasource()
            paramStr = toParam(@granuleDatasource().toQueryParams())
            "#{@details().granule_url}?#{paramStr}"
        deferEvaluation: true

    _computeTimeRange: ->
      if @hasAtomData()
        result = dateUtil.timeSpanToIsoDate(@time_start, @time_end)
      (result || "Unknown")

    _computeSpatial: ->
      (@_spatialString("Bounding Rectangles", @boxes) ?
       @_spatialString("Points", @points) ?
       @_spatialString("Polygons", @polygons) ?
       @_spatialString("Lines", @lines))

    _spatialString: (title, spatial) ->
      if spatial
        suffix = if spatial.length > 1 then " ..." else ""
        "#{title}: #{spatial[0]}#{suffix}"
      else
        null

    _computeGranuleDescription: ->
      result = null
      return result unless @hasAtomData()
      @granuleDatasource()?.granuleDescription() ? 'Collection only'

    _computeOsddUrl: ->
      @osdd_url ? @details()?.osdd_url

    thumbnail: ->
      granule = @browseable_granule
      collection_id = @id for link in @links when link['rel'].indexOf('browse#') > -1
      if collection_id?
        "#{scalerUrl}/datasets/#{collection_id}?h=85&w=85"
      else if granule?
        "#{scalerUrl}/granules/#{granule}?h=85&w=85"
      else
        null

    granuleFiltersApplied: ->
      @granuleDatasource()?.hasQueryConfig()

    shouldDispose: ->
      result = !@granuleFiltersApplied()
      collections.remove(this) if result
      result

    makeRecent: ->
      id = @id
      if id? && !@featured
        ajax
          dataType: 'json'
          url: "/collections/#{id}/use.json"
          method: 'post'
          success: (data) ->
            @featured = data

    granuleDatasourceName: ->
      datasource = @getValueForTag('datasource')
      if datasource
        return datasource
      else if @has_granules
        return "cmr"
      else
        return null

    granuleRendererNames: ->
      renderers = @getValueForTag('renderers')
      if renderers
        return renderers.split(',')
      else if @has_granules
        return ["cmr"]
      else
        return []

    _loadDatasource: ->
      desiredName = @granuleDatasourceName()
      if desiredName && @_currentName != desiredName
        @_currentName = desiredName
        @_unloadDatasource()
        onload = (PluginClass, facade) =>
          datasource = new PluginClass(facade, this)
          @_currentName = desiredName
          @granuleDatasource(@disposable(datasource))

        oncomplete = =>
          if @_datasourceListeners
            for listener in @_datasourceListeners
              listener(@granuleDatasource())
            @_datasourceListeners = null

        edscplugin.load "datasource.#{desiredName}", onload, oncomplete

    _unloadDatasource: ->
      if @granuleDatasource()
        @granuleDatasource().destroy()
        @granuleDatasource(null)

    granuleDatasourceAsync: (callback) ->
      if !@canFocus() || @granuleDatasource()
        callback(@granuleDatasource())
      else
        @_datasourceListeners ?= []
        @_datasourceListeners.push(callback)

    getValueForTag: (key) ->
      if @json.tags
        for [k, v] in @json.tags
          return v if k == "#{config.cmrTagNamespace}#{key}"
      null

    canFocus: ->
      @hasAtomData() && @granuleDatasourceName()

    fromJson: (jsonObj) ->
      @json = jsonObj

      @short_name = ko.observable('N/A') unless jsonObj.short_name

      @hasAtomData(jsonObj.short_name?)
      @_setObservable('gibs', jsonObj)
      @_setObservable('opendap', jsonObj)
      @_setObservable('modaps', jsonObj)
      @_setObservable('osdd_url', jsonObj)

      @nrt = jsonObj.collection_data_type == "NEAR_REAL_TIME"
      @granuleCount(jsonObj.granule_count)

      for own key, value of jsonObj
        this[key] = value unless ko.isObservable(this[key])

      @_loadDatasource()
      @granuleDatasource()?.updateFromCollectionData?(jsonObj)

    _setObservable: (prop, jsonObj) =>
      this[prop] ?= ko.observable(undefined)
      this[prop](jsonObj[prop] ? this[prop]())

  exports = Collection
