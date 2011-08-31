/**
 * Tooltip Plugin for JW Player v5
 * @author Francois Massart, Belgacom Skynet (francois.massart@belgacom.be)
 * @version 2.0
 * 
 * Change log:
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
	import com.longtailvideo.jwplayer.player.*;
	import com.longtailvideo.jwplayer.plugins.*;
	import com.longtailvideo.jwplayer.view.components.*;
	import flash.geom.Point;
	import flash.net.URLRequest;
	
	import flash.display.*;
	import flash.events.*;
	import flash.text.*;
	
	public class TimeSliderTooltipPlugin extends Sprite implements IPlugin 
	{
		[Embed(source="tooltip.png")]
		private const TimeSliderToolTipBackground:Class;
		
		private var _player:IPlayer;
		private var _config:PluginConfig;
		
		private var _duration:int = -1;
		private var _capLeftWidth:Number = 0;
		private var _timeSlider:DisplayObject;
		private var _tooltip:Sprite;
		private var _txt:TextField;
		
		private var _bg:DisplayObject;
		
		
		/** Let the player know what the name of your plugin is. **/
		public function get id():String 
		{
			return "timeslidertooltipplugin"; 
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
			
			parseConfig();
			
			// Event listeners
			_player.addEventListener(MediaEvent.JWPLAYER_MEDIA_TIME, onMediaTimeHandler);
			
			_config['image'] = ( undefined == _config['image']) ? "" : _config['image'];
			if ( "" != _config['image'] )
			{
				var ldr:Loader = new Loader();
				ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, onImagePreloadingDone);
				ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onImagePreloadingDone);
				ldr.load(new URLRequest(_config['image']));
			}
			else
			{
				onImagePreloadingDone(null);
			}
		}
		
		/**
		 * When the image has been loaded use it or fallback to default if IO_ERROR
		 */
		public function onImagePreloadingDone(event:Event):void 
		{
			try
			{
				if ( Event.COMPLETE === event.type )
				{
					_bg = LoaderInfo(event.target).content;
				}
			}
			catch (error:Error)
			{
				
			}
			finally
			{
				createTooltip();
				setupTooltip();
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
		
		private function createTooltip():void
		{
			if ( null == _tooltip )
			{
				// Initialize tooltip
				// ==================
				_tooltip = new Sprite();
				_tooltip.mouseEnabled = _tooltip.mouseChildren = false;
				// Background
				// ==========
				if (null == _bg)
				{	// Fall back to default assets (Skin, then default)
					
					// Element available in the current skin ?
					var bgSkin:DisplayObject = bgSkin = _player.skin.getSkinElement(this.id, "timerSliderTooltipBackground");
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
				_tooltip.addChild(_bg);
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
				if (!isNaN(labelHeight))
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
				_txt.width = _bg.width;
				_txt.height = labelHeight;
				_txt.x = _bg.x;
				_txt.y = _bg.y;
				_txt.multiline = false;
				_tooltip.addChild(_txt);
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
			{	// Probbaly an old skin
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
				
				_txt.text = toTimeString(Math.round(percent * _duration));
				
				var global_pt:Point = _timeSlider.localToGlobal(new Point(event.localX, event.localY));
				var local_pt:Point = _tooltip.parent.globalToLocal(global_pt);
				_tooltip.x = local_pt.x;
				_tooltip.visible = true;
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
