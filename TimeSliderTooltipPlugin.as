/**
 * Tooltip Plugin for JW Player v5
 * @author Francois Massart, Belgacom Skynet (francois.massart@belgacom.be)
 * @version 3.0
 * 
 * Change log:
 * 
 * 2012/05/02 v3.0
 * Bug fix for parameters + Bug fix for iOS poster not showing
 * 
 * 2012/04/20 v3.0
 * Bug fix for the new preview feature when using playlists
 * 
 * 2012/03/19 v3.0
 * Bug fix for the new preview feature
 * 
 * 2012/03/19 v2.1
 * Testing the new preview feature
 * 
 * 2011/09/01 v2.0
 * Supporting new setting for JavaScript plugin "image".
 * 
 * 2011/04/26 v1.1.005
 * Using H:MM:SS when media duration is longer than 59min59sec... (instead of MM:SS)
 * and when the new setting "displayhours" has been set to true.
 * 
 * 2011/03/31 v1.1.004
 * Refactoring: removing unused vars...
 * +
 * Update tooltip content after new time is detected (ex. new media playing, eg. playlist)
 * 
 * 2011/03/30 v1.1.003
 * New settings available for skinning...
 * labelheight		Adjust the height of the tooltip's label... default is 17.
 * font				Choose the font family, default value is "Arial".
 * fontsize			Adjust the font size, default value is 10.
 * fontcolor		Change the font color, the default value is black (0x000000).
 * fontweight		The font weight for the Tooltip's label. (normal, bold)
 * fontstyle		The font style for the Tooltip's label. (normal, italic)
 * 
 * 2011/03/29 v1.1.002
 * Fixing issue on the x position of the tooltip when using a playlist...
 * Now using localToGlobal & globalToLocal...
 * 
 * 2011/03/29 v1.1.001
 * Fixing issue on player version 5.1... 
 * Using this version, the video did autostart no matter what the configuration was and...
 * was only showing a black screen until the video reached the end and display the poster image.
 * _player.play(); was removed
 */
package
{
	import com.longtailvideo.jwplayer.events.*;
	import com.longtailvideo.jwplayer.model.*;
	import com.longtailvideo.jwplayer.player.*;
	import com.longtailvideo.jwplayer.plugins.*;
	import com.longtailvideo.jwplayer.view.components.*;
	
	import flash.net.URLRequest;
	import flash.display.*;
	import flash.events.*;
	import flash.geom.*;
	import flash.system.*;
	import flash.text.*;
	import flash.external.*;
	
	public class TimeSliderTooltipPlugin extends Sprite implements IPlugin 
	{
		[Embed(source="tooltip.png")]
		private const TimeSliderToolTipBackground:Class;
		
		[Embed(source="preview-tooltip.png")]
		private const TimeSliderToolTipPreviewBackground:Class;
		
		private var _player:IPlayer;
		private var _config:PluginConfig;
		
		private var _duration:int = -1;
		private var _capLeftWidth:Number = 0;
		private var _timeSlider:DisplayObject;
		private var _tooltip:Sprite;
		private var _preview:Sprite;
		private var _previewMask:Sprite;
		private var _txt:TextField;
		
		private var _bg:DisplayObject;
		private var _previewBg:DisplayObject;
		private var _previewVisible:Boolean;
		private var _lastMouseMovePosition:Object;
		private var _loadingScreen:Sprite;
		
		private var _pool:Object = {};
		private var _preloadQueue:Array;
		private var _preloader:Loader;
		private var _context:LoaderContext;
		
		/** Let the player know what the name of your plugin is. **/
		public function get id():String 
		{
			return "timeslidertooltipplugin"; 
		}
		
		private function info(msg:Object):void
		{
			//ExternalInterface.call('console.info', msg);
		}
		
		/** Constructor **/
		public function TimeSliderTooltipPlugin() 
		{
		}
		
		/**
		 * Called by the player after the plugin has been created.
		 *  
		 * @param player A reference to the player's API
		 * @param config The plugin's configuration parameters.
		 */
		public function initPlugin(player:IPlayer, config:PluginConfig):void 
		{
			_player = player;
			_config = config;
			
			_context = new LoaderContext();
			_context.checkPolicyFile = false; // bypass security sandbox / policy file
			
			parseConfig();
			
			// Event listeners
			_player.addEventListener(MediaEvent.JWPLAYER_MEDIA_TIME, onMediaTimeHandler);
			_player.addEventListener(PlaylistEvent.JWPLAYER_PLAYLIST_ITEM, onPlaylistItemHandler);
			
			saveLastMouseMove();
			_preloadQueue = new Array();
			_config['image'] = ( undefined == _config['image']) ? "" : _config['image'];
			if ( "" != _config['image'] )
			{
				_preloadQueue.push({target:'_bg', url:_config['image']});
			}
			if ( "" != _config.preview['image'] )
			{
				_preloadQueue.push({target:'_previewBg', url:_config.preview['image']});
			}
			launchNextPreloadQueue();
		}
				
		private function launchNextPreloadQueue():void
		{
			if(0 == _preloadQueue.length)
			{
				createTooltip();
				setupTooltip();
			} 
			else 
			{
				if(null == _preloader)
				{
					_preloader = new Loader();
					_preloader.contentLoaderInfo.addEventListener(Event.COMPLETE, onImagePreloadingDone);
					_preloader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onImagePreloadingDone);
				}
				_preloader.load(new URLRequest(_preloadQueue[0].url), _context);
			}
		}
		
		/**
		 * When the image has been loaded use it or fallback to default if IO_ERROR
		 */
		public function onImagePreloadingDone(event:Event):void 
		{
			try
			{
				var obj:Object = _preloadQueue.shift();
				var var_str:String = obj['target'];
				if ( Event.COMPLETE === event.type )
				{
					
					this[var_str] = LoaderInfo(event.target).content;
				}
			}
			catch (error:Error)
			{
				
			}
			finally
			{
				launchNextPreloadQueue();
			}
		}
		
		/**
		 * When the player resizes itself, it sets the x/y coordinates of all components and plugins.  
		 * Then it calls resize() on each plugin, which is then expected to lay itself out within 
		 * the requested boundaries.  Plugins whose position and size are not set by flashvar configuration
		 * receive the video display area's dimensions in resize().
		 *  
		 * @param width Width of the plugin's layout area, in pixels 
		 * @param height Height of the plugin's layout area, in pixels
		 */		
		public function resize(w:Number, h:Number):void 
		{
		}
		
		private function parseConfig():void
		{
			// New feature "Preview"
			var user_cfg:Object = _config["preview"];
			
			// Default values
			var preview_cfg:Object = {};
				preview_cfg.preloadtext = "Loading...";
				preview_cfg.extension = "jpg";
				preview_cfg.preload = false;
				preview_cfg.cache = true;
			var frequency:Number;
			var linelength:Number;
			var spritelength:Number;
				
			if( 'undefined' == user_cfg || null == user_cfg ) 
			{
				// OLD WAY NOTATION
				preview_cfg.enabled = ("true"==String(_config['preview.enabled'])) ? true : false;
				preview_cfg.path = String(_config['preview.path']);
				preview_cfg.path = ("undefined"==preview_cfg.path) ? null : preview_cfg.path;
				preview_cfg.prefix = String(_config['preview.prefix']);
				preview_cfg.prefix = ("undefined"==preview_cfg.prefix) ? null : preview_cfg.prefix;
				preview_cfg.image = String(_config['preview.image']);
				preview_cfg.image = ("undefined"==preview_cfg.image) ? "" : preview_cfg.image;
				frequency = Number(_config['preview.frequency']);
				if (isNaN(frequency)) { frequency = 1; }
				preview_cfg.frequency = Math.round(frequency);
				linelength = Number(_config['preview.linelength']);
				if (isNaN(linelength)) { linelength = 5; }
				preview_cfg.linelength = Math.round(linelength);
				spritelength = Number(_config['preview.spritelength']);
				if (isNaN(spritelength)) { spritelength = 25; }
				preview_cfg.spritelength = Math.round(spritelength);
			} else {
				// NEW NOTATION
				preview_cfg.enabled = ("true" == String(user_cfg.enabled)) ? true : false;
				
				// Path
				if(undefined==user_cfg.path) {
					preview_cfg.path = null;
				} else {
					preview_cfg.path = user_cfg.path;
				}
				
				// Prefix
				if(undefined==user_cfg.prefix) {
					preview_cfg.prefix = null;
				} else {
					preview_cfg.prefix = user_cfg.prefix;
				}
				
				// Image
				preview_cfg['image'] = ( undefined == user_cfg['image']) ? "" : user_cfg['image'];
				
				// Frequency
				frequency = Number(user_cfg['frequency']);
				preview_cfg['frequency'] = ( isNaN(frequency) ) ? 1 : frequency;
				
				// Linelength
				linelength = Number(user_cfg['linelength']);
				preview_cfg['linelength'] = ( isNaN(linelength) ) ? 5 : linelength;
				
				// Spritelength
				spritelength = Number(user_cfg['spritelength']);
				preview_cfg['spritelength'] = ( isNaN(spritelength) ) ? 25 : spritelength;
			}
			info(preview_cfg);
			_config["preview"] = preview_cfg;
			
			// DisplayHours
			var displayhours:Boolean = false;
			try
			{
				if ("true" == String(_config["displayhours"]))
				{
					displayhours =  true;
				}
			}
			catch (e:Error)
			{
				
			}
			finally 
			{
				_config["displayhours"] = displayhours;
			}
		}
		
		private function getCurrentFile():String
		{
			// Get the playlist
			var list:IPlaylist = _player.playlist;
			// The currently playing item's file URL
			return list.currentItem.file;
		}
		private function getPath():String
		{
			var path_str:String;
			if ( null==_config.preview.path )
			{
				var currentFile:String = getCurrentFile();
				path_str = currentFile.substr(0, currentFile.lastIndexOf('/')+1)
			}
			else
			{
				path_str = _config.preview.path;
			}
			return path_str;
		}
		
		private function getPrefix():String
		{
			var prefix_str:String;
			if ( null==_config.preview.prefix )
			{
				var currentFile:String = getCurrentFile();
				var filename:String = currentFile.substr(currentFile.lastIndexOf('/')+1, currentFile.length);
				var lastDot:int = filename.lastIndexOf('.');
				if(0 < lastDot) {
					filename = filename.substr(0, lastDot);
				}
				prefix_str = filename;
			}
			else
			{
				prefix_str = _config.preview.prefix;
			}
			return prefix_str;
		}
		
		private function createTooltip():void
		{
			if ( null == _tooltip )
			{
				// Initialize tooltip
				// ==================
				_tooltip = new Sprite();
				_tooltip.mouseEnabled = _tooltip.mouseChildren = false;
				// Backgrounds
				// ===========
				if (null == _bg)
				{	// Fall back to default assets (Skin, then default)
					// Element available in the current skin ?
					var bgSkin:DisplayObject = _player.skin.getSkinElement(this.id, "timerSliderTooltipBackground");
					if (null == bgSkin)
					{
						_bg = new TimeSliderToolTipBackground();
					}
					else
					{
						_bg = bgSkin;
					}
				}
				_bg.x = -_bg.width / 2;
				_bg.y = -_bg.height;
				if (null == _previewBg)
				{	// Fall back to default assets (Skin, then default)
					// Element available in the current skin ?
					var previewBgSkin:DisplayObject = _player.skin.getSkinElement(this.id, "timerSliderTooltipPreviewBackground");
					if (null == previewBgSkin)
					{
						_previewBg = new TimeSliderToolTipPreviewBackground();
					}
					else
					{
						_previewBg = previewBgSkin;
					}
				}
				_previewBg.x = -_previewBg.width / 2;
				_previewBg.y = -_previewBg.height;
				// Margin bottom
				// =============
				var tooltipY:Number = Number(_config['marginbottom']);
				if (!isNaN(tooltipY))
				{
					_tooltip.y = tooltipY;
				}
				// Label height
				// =============
				var labelHeight:Number = Number(_config['labelheight']);
				if (isNaN(labelHeight))
				{
					labelHeight = 17;
				}
				// Font
				// ====
				var fontName:String = _config['font'];
				if (null==fontName)
				{
					fontName = "Arial";
				}
				// Font size
				// =========
				var fontSize:Number = Number(_config['fontsize']);
				if (isNaN(fontSize))
				{
					fontSize = 10;
				}
				// Font color
				// ==========
				var fontColor:uint = uint(_config['fontcolor']);
				if (isNaN(fontColor))
				{
					fontColor = 0x000000;
				}
				// Font weight
				// ===========
				var fontWeight:String = String(_config['fontweight']);
				if (fontWeight!="normal" && fontWeight!="bold")
				{
					fontWeight = "normal";
				}
				// Font style
				// ==========
				var fontStyle:String = String(_config['fontstyle']);
				if (fontStyle!="normal" && fontStyle!="italic")
				{
					fontStyle = "normal";
				}
				
				// Label
				// =====
				_txt = new TextField();
				var tf:TextFormat = new TextFormat(fontName, fontSize, fontColor, ("bold"===fontWeight), ("italic"===fontStyle));
				tf.align = TextFormatAlign.CENTER;
				_txt.defaultTextFormat = tf;
				_txt.height = labelHeight;
				_txt.multiline = false;
				
				// Preview
				// =======
				_preview = new Sprite();
				_previewMask = new Sprite();
				_preview.x = _previewMask.x = _previewBg.x + 2;
				_preview.y = _previewMask.y = _previewBg.y + 2;
				_previewMask.graphics.beginFill(0xFF0000);
				_previewMask.graphics.drawRect(0, 0, 108, 60);
				_tooltip.addChild(_previewMask);
				_tooltip.addChild(_preview);
				_preview.mask = _previewMask;
				
				_loadingScreen = new Sprite();
				_loadingScreen.graphics.lineStyle(0,0x000000);
				_loadingScreen.graphics.beginFill(0x000000);
				_loadingScreen.graphics.drawRect(0,0,108,60);
				_loadingScreen.graphics.endFill();
				var loading_txt:TextField = new TextField();
				var loading_tf:TextFormat = new TextFormat(fontName, fontSize, 0xFFFFFF, true);
				loading_tf.align = TextFormatAlign.CENTER;
				loading_txt.defaultTextFormat = loading_tf;
				loading_txt.width = 108;
				loading_txt.height = labelHeight;
				loading_txt.backgroundColor = 0x000000;				
				loading_txt.background = true;				
				info(labelHeight);
				loading_txt.y = (60 - labelHeight) / 2;
				loading_txt.multiline = false;
				loading_txt.text = _config.preview.preloadtext;
				_loadingScreen.addChild(loading_txt);
			}
			
			_previewVisible = !_config.preview.enabled;
			updateTooltipUI(_config.preview.enabled);
		}
		
		private function updateTooltipUI(withPreview:Boolean):void {
			if(withPreview!=_previewVisible) {
				_previewVisible = withPreview;
				
				// Reset children
				_tooltip.addChild(_bg);
				_tooltip.removeChild(_bg);
				_tooltip.addChild(_previewBg);
				_tooltip.removeChild(_previewBg);
				
				var targetBg:DisplayObject = withPreview ? _previewBg : _bg;
				_tooltip.addChild(targetBg);
				_txt.x = targetBg.x;
				_txt.y = (withPreview) ? targetBg.y+62 : targetBg.y;
				_txt.width = targetBg.width;
				_tooltip.addChild(_txt);
				
				// Preview
				// =======
				_tooltip.addChild(_preview);
				//_preview.mask = _previewMask;
				if(!withPreview) {
					_tooltip.removeChild(_preview);
				}
			}
		}
				
		private function setupTooltip():void
		{
			var dsp:DisplayObject;
			var time_doc:DisplayObjectContainer;
			
			if (_player.skin.hasComponent("controlbar"))
			{	// Recent skin
				time_doc = _player.controls.controlbar.getButton("time") as DisplayObjectContainer;
				_timeSlider = time_doc.getChildByName("clickarea") as DisplayObject;
				_tooltip.x = _timeSlider.x + time_doc.x;
				dsp = time_doc.getChildByName("capleft");
				if ( null != dsp )
				{
					_capLeftWidth = dsp.width;
				}
			}
			else
			{	// Probably an old skin
				if (_player.controls.controlbar is ControlbarComponentV4)
				{	// ControlbarComponentV4
					var controlbar:DisplayObjectContainer = DisplayObjectContainer(_player.controls.controlbar).getChildByName("controlbar") as DisplayObjectContainer;
					_timeSlider = controlbar.getChildByName("timeSlider") as DisplayObject;
					_tooltip.x = _timeSlider.x;
				}
			}
			
			if (null != _timeSlider)
			{
				_timeSlider.addEventListener(MouseEvent.MOUSE_OVER, onMouseHandler);
				_timeSlider.addEventListener(MouseEvent.MOUSE_OUT, onMouseHandler);
				_timeSlider.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMoveHandler);
				
				if (_duration < 0) { _tooltip.visible = false; }
				
				DisplayObjectContainer(_player.controls.controlbar).addChild(_tooltip);
			}			
		}
		
		private function onMediaTimeHandler(event:MediaEvent):void 
		{
			_duration = event.duration;
			
			var global_pt:Point = _tooltip.parent.localToGlobal(new Point(_tooltip.x, _tooltip.y));
			var timeSlide_pt:Point = _timeSlider.globalToLocal(global_pt);
			
			var pos:Number = timeSlide_pt.x - _capLeftWidth;
			var percent:Number = pos / _timeSlider.width;
			
			_txt.text = toTimeString(Math.round(percent * _duration));
		}
		
		private function onPlaylistItemHandler(event:PlaylistEvent):void 
		{
			info("onPlaylistItemHandler()");
			_pool = {};
		}
		
		private function onMouseHandler(event:MouseEvent):void 
		{
			_tooltip.visible = (MouseEvent.MOUSE_OVER === event.type && 0 < _duration);
		}
		
		private function onMouseMoveHandler(event:MouseEvent):void 
		{
			if ( 0 < _duration )
			{
				var pos:Number = event.localX - _capLeftWidth;
				var percent:Number = pos / _timeSlider.width;
				var seconds:int = Math.round(percent * _duration);
				
				_txt.text = toTimeString(seconds);
				
				// Preview
				if(_config.preview.enabled) {
					var pt:Point = getSpriteCoordinates(seconds);
					var url:String = getPreviewSpriteUrl(seconds);
					
					setPreviewContent(pt, url);
				}
				
				var global_pt:Point = _timeSlider.localToGlobal(new Point(event.localX, event.localY));
				var local_pt:Point = _tooltip.parent.globalToLocal(global_pt);
				_tooltip.x = local_pt.x;
				_tooltip.visible = true;
			}
		}
		
		private function saveLastMouseMove(pt:Point = null, url:String = ""):void
		{
			if(null==_lastMouseMovePosition) 
			{
				_lastMouseMovePosition = {};
			}
			_lastMouseMovePosition.pt = pt;
			_lastMouseMovePosition.url = url;			
		}
		
		private function setPreviewContent(pt:Point = null, url:String = ""):void
		{
			pt = (null==pt) ? _lastMouseMovePosition.pt : pt;
			url = (""==url) ? _lastMouseMovePosition.url : url;
			if(null!=pt && ""!=url)
			{
				var img:* = getImageFromPool(url);
				var found:Boolean = (img is DisplayObject);
				if(found)
				{
					// Image loaded and ready!
					img.x = -pt.x*108;
					img.y = -pt.y*60;
					_preview.addChild(img);
					saveLastMouseMove();
				}
				else if( 0 === img )
				{
					// Image loading
					_preview.addChild(_loadingScreen);
					saveLastMouseMove(pt, url);
				}
				//updateTooltipUI(found);
				updateTooltipUI(-1!=img);
			}
			else
			{
				updateTooltipUI(false);
			}
		}
		
		private function loadSprite(url:String):void
		{
			var ldr:Loader = new Loader();
			var urlReq:URLRequest = new URLRequest(url);
			//ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onSpriteLoadingDone);
			ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(req:URLRequest):Function {
				return function(event:Event):void {
					onSpriteLoadingDone(event, req.url);
				}
			}(urlReq));
			ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, function(req:URLRequest):Function {
				return function(event:Event):void {
					onSpriteLoadingDone(event, req.url);
				}
			}(urlReq));
			ldr.load(urlReq, _context);
		}
		
		private function onSpriteLoadingDone(event:Event, relativeUrl:String = null):void 
		{
			var ldrinfo:LoaderInfo;
			var src:String;
			var prop:String;
			try
			{
				ldrinfo = LoaderInfo(event.target);
				src = ( null == relativeUrl ) ? ldrinfo.url : relativeUrl;
				prop = getPropertyFromPath(src);
				_pool[prop] = -1;
			
				if ( Event.COMPLETE === event.type )
				{
					_pool[prop] = ldrinfo.loader; //Using ldrinfo.content fails with a security error
				}
			}
			catch (error:Error)
			{
				info("error");
				info(error);
			}
			finally
			{
				info("Finally "+prop+" ("+_pool[prop]+")");
				setPreviewContent();
			}
		}
		
		private function getPropertyFromPath(path:String):String
		{
			var endPos:int = path.length - 4; // removing .jpg
			var startPos:int = endPos - 4; // saving the 4 digits
			return "image"+path.substring(startPos, endPos);
		}
		
		private function getSpriteCoordinates(seconds:int):Point
		{
			var sec:uint = Math.floor(seconds / _config.preview.frequency);
			var ratio:Number = (_config.preview.spritelength / _config.preview.linelength);
			var pt:Point = new Point();
			pt.x = sec % _config.preview.linelength;
			pt.y = Math.floor( sec / _config.preview.linelength ) % ratio;
            return pt;
        }
		
		private function getPreviewSpriteUrl(seconds:int):String
		{
			seconds = (0 > seconds) ? 0 : seconds;
			var n:Number = seconds / _config.preview.frequency / _config.preview.spritelength;
			var url:String = getPath();
			url += getPrefix();
			url += pad(Math.floor(n), 4);
			url += "."+_config.preview.extension;
            return url;
        }
		
		private function getImageFromPool(src:String):* {
			//-1				The image loading failed to load
			// 0				The image loading is pending
			// DisplayObject	The image loading was successful
			
			var prop:String = getPropertyFromPath(src);
			if ( 'undefined' == typeof(_pool[prop]) )
			{
				_pool[prop] = 0;
				loadSprite(src);
				return 0;
			} else {
				return _pool[prop];
			}
		}
				
		private function toTimeString(n:int):String
		{
			var time_str:String = "";
			if (n >= 3600 && true===Boolean(_config['displayhours']))
			{	// Longer than one hour
				var hours:uint = Math.floor(n / 3600);
				time_str += Math.floor(n / 3600) + ":";
				n -= 3600 * hours;
			}
			time_str += pad(Math.floor(n / 60), 2) + ":" + pad(Math.floor(n % 60), 2);
			return time_str;
		}
		
		private function pad(n:Number, padLength:uint):String
		{
			var str:String = n.toString();
			while ( str.length < padLength )
			{
				str = "0" + str;
			}
			return str;
		}
	}
}
