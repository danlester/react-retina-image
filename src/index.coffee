{crel} = require 'teact'
React = require 'react'
PropTypes = require 'prop-types'
isRetina = require 'is-retina'
imageExists = require 'image-exists'
path = require 'path'
assign = require 'object-assign'
arrayEqual = require 'array-equal'

module.exports = class RetinaImage extends React.Component

  @propTypes:
    src: PropTypes.oneOfType([
      PropTypes.string
      PropTypes.array
    ]).isRequired
    checkIfRetinaImgExists: PropTypes.bool
    forceOriginalDimensions: PropTypes.bool
    retinaImageSuffix: PropTypes.string
    handleOnLoad: PropTypes.func # Deprecated.
    onLoad: PropTypes.func
    onError: PropTypes.func

  @defaultProps:
    checkIfRetinaImgExists: true
    forceOriginalDimensions: true
    retinaImageSuffix: '@2x'
    onError: ->

  constructor: (props) ->
    @_isMounted = false
    super props
    @state = @wrangleProps()
    @imgref = React.createRef()

  componentDidUpdate: (prevProps, prevState) ->
    isEqual = true
    if Array.isArray(@props.src) and Array.isArray(prevProps.src)
      isEqual = arrayEqual(@props.src, prevProps.src)
    else
      isEqual = @props.src is prevProps.src

    unless isEqual
      @setState assign @wrangleProps(@props), {
        width: null
        height: null
        imgLoaded: null
        retinaImgExists: null
        retinaCheckComplete: null
      }

  componentDidMount: ->
    @_isMounted = true
    @checkForRetina()
    @checkLoaded()

  componentWillUnmount: ->
    @_isMounted = false

  componentDidUpdate: ->
    @checkForRetina()

  render: ->
    # Propagate only the props that `<img>` supports, avoid React `Unknown props` warning. https://fb.me/react-unknown-prop
    # CoffeeScript does not support splat `...` for object destructuring so using `assign` and `delete`. http://stackoverflow.com/a/20298038
    imgProps = assign {}, @props
    delete imgProps.src
    delete imgProps.checkIfRetinaImgExists
    delete imgProps.forceOriginalDimensions
    delete imgProps.retinaImageSuffix
    delete imgProps.handleOnLoad
    delete imgProps.onLoad
    delete imgProps.onError

    # Override some of the props for `<img>`.
    imgProps.src = @state.src
    imgProps.onLoad = @handleOnLoad
    imgProps.onError = @props.onError

    if @state.width >= 0
      imgProps.width = @state.width

    if @state.height >= 0
      imgProps.height = @state.height

    crel("img", Object.assign({}, \
      imgProps, { \
      "ref": @imgref}))

  # src can be a href or an array of hrefs.
  wrangleProps: (props=@props) ->
    if Array.isArray(props.src)
      return {
        src: props.src[0]
        srcIsArray: true
      }
    else
      return {
        src: props.src
        srcIsArray: false
      }

  checkForRetina: ->
    if @state.retinaCheckComplete or !@_isMounted then return

    if isRetina() and @props.checkIfRetinaImgExists
      imageExists @getRetinaPath(), (exists) =>
        # If original image has loaded already (we have to wait so we know
        # the original image dimensions), then set the retina image path.
        if exists and @state?.imgLoaded
          @setState src: @getRetinaPath()
        else if exists
          @setState retinaImgExists: true

        @setState retinaCheckComplete: true

    # If the check isn't needed, immediately swap in the retina path
    else if isRetina() and not @props.checkIfRetinaImgExists
      @setState src: @getRetinaPath()

      @setState retinaCheckComplete: true

  # For server-rendered code, sometimes images will already be loaded by the time
  # this module mounts.
  # http://stackoverflow.com/a/1977898
  checkLoaded: ->
    el = @imgref

    unless el.complete
      return false

    if el.naturalWidth is 0
      return false

    # No other way to disprove it's loaded so we'll assume it's ok.
    @handleOnLoad()


  handleOnLoad: (e) =>
    if !@_isMounted then return

    # Customers of component might care when the image loads.
    if @props.onLoad?
      @props.onLoad(e)
    # handleOnLoad was in an earlier version (wrong name) and will be removed
    # at the next major release.
    if @props.handleOnLoad?
      @props.handleOnLoad(e)

    if @props.forceOriginalDimensions
      @setState {
        width: @imgref.clientWidth
        height: @imgref.clientHeight
      }

    @setState imgLoaded: true

    # If the retina image check has already finished, set the 2x path.
    if @state?.retinaImgExists or not @props.checkIfRetinaImgExists
      @setState src: @getRetinaPath()

  getRetinaPath: ->
    if @state.srcIsArray
      return @props.src[1]
    else
      basename = path.basename(@props.src, path.extname(@props.src))
      basename = basename + @props.retinaImageSuffix + path.extname(@props.src)
      src = @props.src.replace(path.basename(@props.src), basename)
      return src
