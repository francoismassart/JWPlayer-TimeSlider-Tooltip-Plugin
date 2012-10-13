(function (jwplayer) {
    var template = function (player, config, div) {
        var _div = div,
			_dotNotation = _detectOldNotation(),
            // Cached elements references to HTML nodes
            _controlbar = null,
            _rail = null,
            _preview = null,
            _time = null,
            // Safety flags...
            _ready = false,
            _previewVisible,
            // Cache
            _pool = {},
            _preloadQueue,
            _preloader = null,
			_jw = jwplayer.utils;
        
        function setup(evt) {
            // Setting variables
            _controlbar = _jw.selectors("#" + player.id + "_jwplayer_controlbar_elements", document);
            _rail = _jw.selectors("#" + player.id + "_jwplayer_controlbar_timeSliderRail", document);
            
			// Parsing the config object
            _parseConfig();
        };
        
        player.onReady(setup);
        
        this.resize = function (width, height) {
			if(null != _div && null != _rail && null != _controlbar) {
				_jw.append(_controlbar, _div);
				// Update Styles
				var map = {};
				var marginBottom = isNaN(config.marginbottom) ? 0 : config.marginbottom;
				var controlBarHeight = _jw.getElementHeight(_controlbar);
				map.bottom = 0 + controlBarHeight + marginBottom + "px";
				map.left = Math.round(width/2) + 'px';
				_jw.css(_div, map);
			}
        };
		
		function _detectOldNotation() {
			for(k in config) {
				if("pluginmode"!=k) {
					return false;
				}
			}
			return true;
		};
        
		function _getConfigValue(prop) {
			if (_dotNotation) {
				return player.config['timeslidertooltipplugin.'+prop];
			} else {
				var arr = prop.split(".");
				var tot = arr.length;
				var val = config;

				for(var i = 0;  i < tot; i++) {
					val = val[arr[i]];
					if(i+1>=tot) {
						return val;
					}
				}
			}
		};
        	
        function _parseConfig() {
            _preloadQueue = new Array();
			
			// displayhours (H:MM:SS or MM:SS)
			config.displayhours = ("true" == String(_getConfigValue('displayhours'))) ? true : false;
			
			// marginbottom (adjusts the vertical position of the tooltip % to the controlbar)
			var marginBottom = parseInt(_getConfigValue('marginbottom'));
			config.marginbottom = isNaN(marginBottom) ? 0 : marginBottom;
			
			// labelheight
			var labelHeight = parseInt(_getConfigValue('labelheight'));
			config.labelheight = (isNaN(labelHeight)) ? 17 : labelHeight;
			
			// font, fontsize, fontcolor, fontweight, fontstyle
			var fontFamily = _getConfigValue('font');
			config.font = (!fontFamily) ? "Arial,sans-serif" : fontFamily;
			var fontSize = parseInt(_getConfigValue('fontsize'));
			config.fontsize = isNaN(fontSize) ? 11 : fontSize;
			var fontColor = String(_getConfigValue('fontcolor'));
			if (0 === fontColor.indexOf("0x")) {
				fontColor = "#"+fontColor.substr(2);
			}
			config.fontcolor = (!fontColor) ? "#000" : fontColor;
			
			var fontWeight = _getConfigValue('fontweight');
			config.fontweight = (fontWeight!="normal" && fontWeight!="bold") ? "normal" : fontWeight;
			
			var fontStyle = _getConfigValue('fontstyle');
			config.fontstyle = (fontStyle!="normal" && fontStyle!="italic") ? "normal" : fontStyle;
			
			// image
			//config.image = (null!=config.image) ? config.image : _getDefaultImage();
			var imageSrc = _getConfigValue('image');
			config.image = (null!=imageSrc && 'undefined'!=imageSrc) ? imageSrc : "";
			if (""!=config.image) {
				_preloadQueue.push({target:'config.image', url:config.image});
			}
			
			// New feature "Preview"
			// =====================
			// Enabled
			var enabled = ("true" == String(_getConfigValue('preview.enabled'))) ? true : false;
			// Path
			var file = player.getPlaylistItem().file;
			var path = String(_getConfigValue('preview.path'));
			// Prefix
			var prefix = String(_getConfigValue('preview.prefix'));
			// Image
			var previewImageSrc = String(_getConfigValue('preview.image'));
			previewImageSrc = (null!=previewImageSrc && 'undefined'!=previewImageSrc) ? previewImageSrc : "";
			var frequency = parseInt(_getConfigValue('preview.frequency'));
			var linelength = parseInt(_getConfigValue('preview.linelength'));
			var spritelength = parseInt(_getConfigValue('preview.spritelength'));
			// Setting values
			config.preview = {};
			config.preview.preloadtext = "Loading...";
			config.preview.extension = "jpg";
			config.preview.preload = false;
			config.preview.cache = true;
			// User settings
			config.preview.enabled = enabled;
			config.preview.path = path;
			config.preview.prefix = prefix;
			config.preview.image = previewImageSrc;
			if ('undefined'==config.preview.path) {
				config.preview.path = null;
			}
			if ('undefined'==config.preview.prefix) {
				config.preview.prefix = null;
			}
			if (""!=config.preview.image) {
				_preloadQueue.push({target:'config.preview.image', url:config.preview.image});
			}
			if (isNaN(frequency)) {
				config.preview.frequency = 1;
			}else{
				config.preview.frequency = frequency;
			}
			if (isNaN(linelength)) {
				config.preview.linelength = 5;
			}else{
				config.preview.linelength = linelength;
			}
			if (isNaN(spritelength)) {
				config.preview.spritelength = 25;
			}else{
				config.preview.spritelength = spritelength;
			}
			
            _launchNextPreloadQueue();
        };
        
        function _launchNextPreloadQueue() {
            if (0 == _preloadQueue.length) {
                // Create the Tooltip
                _createTooltip();
                
                // If everything went fine...
                if ( null != _rail && null != _controlbar ) {
                    _ready = true;
                    _jw.append(_controlbar, _div);
                    _controlbar.addEventListener('mousemove', _mousemove);
                    _controlbar.addEventListener('mouseout', _mouseout);
                }
            } else {
                if (null == _preloader) {
                    _preloader = new Image();
                    _preloader.onload = _onImagePreloadingDone;
                    _preloader.onerror = _onImagePreloadingDone;
                }
                _preloader.src = _preloadQueue[0].url;
            }
        };
        
        function _onImagePreloadingDone(event) {
            var obj = _preloadQueue.shift();
            var var_str = obj['target'];
            switch ( event.type ) {
                case "load":
                    break;
                case "error":
                    // Overwrite the user settings because image was not loaded
                    // We fall back to default backgrounds in this case...
                    if ("config.image"==var_str) {
                        config.image = "";
                    } else if ("config.preview.image"==var_str){
                        config.preview.image = "";
                    }
                    break;
            }
            _launchNextPreloadQueue();
        };
        
		function _getCurrentFile() {
			// The currently playing item's file URL
			return player.getPlaylistItem().file;;
		};
		
		function _getPath() {
			var path_str;
			if ( null==config.preview.path ) {
				var currentFile = _getCurrentFile();
				path_str = currentFile.substr(0, currentFile.lastIndexOf('/')+1)
			} else {
				path_str = config.preview.path;
			}
			return path_str;
		};
		
		function _getPrefix() {
			var prefix_str;
			if ( null==config.preview.prefix ) {
				var currentFile = _getCurrentFile();
				var filename = currentFile.substr(currentFile.lastIndexOf('/')+1, currentFile.length);
				var lastDot = filename.lastIndexOf('.');
				if(0 < lastDot) {
					filename = filename.substr(0, lastDot);
				}
				prefix_str = filename;
			} else {
				prefix_str = config.preview.prefix;
			}
			return prefix_str;
		};
		        
        function _createTooltip() {
            // Build Markup
            // ============
            _jw.html(_div, '<div class="tstt-preview"></div><span class="tstt-time">...</span>');
            _preview = _jw.selectors.getElementsByTagAndClass('div', 'tstt-preview', _div)[0];
            _time = _jw.selectors.getElementsByTagAndClass('span', 'tstt-time', _div)[0];
            
            _show(false);
            
            var map;
            
            // Applying CSS
            // ============
            
            // General
            map = {};
            map.position = 'absolute';
            map.pointerEvents = "none";
            _jw.css(_div, map);
            
            // Preview
            map = {};
            map.width = '108px'; //160px
            map.height = '60px'; //90px
            map.position = 'absolute';
            map.top = '2px';
            map.left = '2px';
            map.overflow = 'hidden';
            _jw.css(_preview, map);
            
            // Time
            map = {};
            map.display = "block";
            map.color = config.fontcolor;
            map.fontFamily = config.font;
            map.fontSize = config.fontsize + "px";
            map.fontWeight = config.fontweight;
            map.color = config.fontcolor;
            map.fontStyle = config.fontstyle;
            map.textAlign = "center";
            map.lineHeight = config.labelheight + "px";
            map.pointerEvents = "none";
            _jw.css(_time, map);
            
            _updateTooltipUI(config.preview.enabled);
            _previewVisible = config.preview.enabled;
        };
        
        function _updateTooltipUI(withPreview) {
            var map = {};
            if (withPreview!=_previewVisible) {
                _previewVisible = !_previewVisible;
                
                var bg_src = withPreview ? config.preview.image : config.image;
                if (""===bg_src) {
                    // Default Background
                    // ==================
                    if (withPreview) {
                        map.width = "112px";
                        map.height = "82px";
                        map.background = "url('" + _getDefaultPreviewImage() + "') left top no-repeat transparent";
                    } else {
                        map.width = "41px";
                        map.height = "22px";
                        map.background = "url('" + _getDefaultImage() + "') left top no-repeat transparent";
                    }
                    _jw.css(_div, map);
                } else {
                    // Custom background
                    // =================
                    var img = new Image();
                    img.onload = function () {
                        // Resize the tooltip to match the Tooltip background size
                        map.background = "url('" + this.src + "') left top no-repeat transparent";
                        map.width = this.width + "px";
                        map.height = this.height + "px";
                        _jw.css(_div, map);
                    };
                    img.onerror = function () {
                        // Implement fallback to default?
                    };
                    img.src = withPreview ? config.preview.image : config.image;
                }
                
                // Preview
                // =======
                if (withPreview) {
                    _preview.style.display = "block";
                    _time.style.marginTop = "62px";
                } else {
                    _preview.style.display = "none";
                    _time.style.marginTop = "0px";
                }
            }
        };
        
        function _show(state) {
            div.style.display = (false===state) ? "none" : "block";
        };
        
        function _mousemove(event) {
            var dur = player.getDuration();
            if (_ready && dur > 0) {
                var railOffset = _jw.getBoundingClientRect(_rail);
                var x_pos = event.pageX - railOffset.left;
                var width = _jw.getElementWidth(_rail);
                var percent = x_pos/width;
                var parentDiv = _jw.parentNode(_div);
                var parentOffset = _jw.getBoundingClientRect(parentDiv);
                var tooltip_x = event.pageX - parentOffset.left;
                var seconds = Math.round(percent*dur);
                // Preview
                if (config.preview.enabled) {
                    var pt = _getSpriteCoordinates(seconds);
                    var url = _getPreviewSpriteUrl(seconds);
                    var map = {};
                    map.backgroundImage = "url('"+url+"')";
                    map.backgroundPosition = "-"+(pt.x*108)+"px -"+(pt.y*60)+"px";
                    _jw.css(_preview, map);
                    //_updateTooltipUI(1===_getImageFromPool(url));
                    _updateTooltipUI(-1!=_getImageFromPool(url));
                }
                // Time
                _jw.html(_time, _toTimeString(seconds));
                
                var tooltipWidth = _jw.getElementWidth(_div);
                tooltip_x -= Math.ceil(tooltipWidth/2);
                _div.style.left = tooltip_x + "px";
                _show(x_pos >= 0 && x_pos <= width);
            } else {
                _show(false)
            }
        };
                
        function _getImageFromPool(src) {
        	// Doesn't save the images, just remember if loading failed/succeeded
            //-1    The image loading failed to load
            // 0    The image loading is pending
            // 1    The image loading was successful
            if ('undefined'==typeof(_pool[src])) {
                _pool[src] = 0;
                var pool_img = new Image();
                pool_img.onerror = function () { _pool[src] = -1; };
                pool_img.onload = function () { _pool[src] = 1; };
                pool_img.src = src;
                return 0;
            } else {
                return _pool[src];
            }
        };
        
        function _getPreviewSpriteUrl(seconds) {
            seconds = (0 > seconds) ? 0 : seconds;
			var n = seconds / config.preview.frequency / config.preview.spritelength;
            var url = _getPath();
            url += _getPrefix();
            url += _pad(Math.floor(n), 4);
            url += "."+config.preview.extension;
            return url;
        };
        
        function _getSpriteCoordinates(seconds) {
			var sec = Math.floor(seconds / config.preview.frequency);
			var ratio = (config.preview.spritelength/config.preview.linelength);
            var point = {};
            point.x = sec % config.preview.linelength;
            point.y = Math.floor(sec/config.preview.linelength) % ratio;
            return point;
        };
        
        function _mouseout(event) {
            _show(false);
        };
        
        function _toTimeString(n) {
            var time_str = "";
            if (n >= 3600 && true===config.displayhours) {
                // Longer than one hour
                var hours = Math.floor(n / 3600);
                time_str += Math.floor(n / 3600) + ":";
                n -= 3600 * hours;
            }
            time_str += _pad(Math.floor(n / 60), 2) + ":" + _pad(Math.floor(n % 60), 2);
            return time_str;
        };
        
        function _pad(n, padLength) {
            var str = n.toString();
            while ( str.length < padLength ) {
                str = "0" + str;
            }
            return str;
        };
        
        function _getDefaultImage() {
            return "data:;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAWCAYAAABdTLWOAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyRpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1NzowMSAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNS4xIE1hY2ludG9zaCIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDoyOTJFQjY1QjY4NUQxMUUxODU2NjlGRUZDNTQ3OERBRCIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDoyOTJFQjY1QzY4NUQxMUUxODU2NjlGRUZDNTQ3OERBRCI+IDx4bXBNTTpEZXJpdmVkRnJvbSBzdFJlZjppbnN0YW5jZUlEPSJ4bXAuaWlkOjI5MkVCNjU5Njg1RDExRTE4NTY2OUZFRkM1NDc4REFEIiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjI5MkVCNjVBNjg1RDExRTE4NTY2OUZFRkM1NDc4REFEIi8+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+uNEd5wAAAKlJREFUeNpi/P//PwMQBAKxBxArMgwecBuINwPxDkagI0EOzGQYvKCHCUj4Mwxu4A9yJP8gdyQ/E8MQAKOOHHXkqCNHHTnqyGHiyI+D3I0fQY7cN8gduY8FSCwBYhDtAsQig8hxr0BtSSBeywht9JINHjx4sEtBQYGQGgagGreBzDhuIEfgcyBIzWDI3VgdSg0HUrsIQnEotRwIAhSnSSxgF8zR1DIQIMAAyzExMof0JwMAAAAASUVORK5CYII=";
        };
        
        function _getDefaultPreviewImage() {
            return "data:;base64,iVBORw0KGgoAAAANSUhEUgAAAHAAAABSCAYAAACMhFB2AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyRpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1NzowMSAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNS4xIE1hY2ludG9zaCIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDo0Q0UxRjVDQjY3QTQxMUUxOEJFMkY4QjEyOEYwMDM5OCIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDo0Q0UxRjVDQzY3QTQxMUUxOEJFMkY4QjEyOEYwMDM5OCI+IDx4bXBNTTpEZXJpdmVkRnJvbSBzdFJlZjppbnN0YW5jZUlEPSJ4bXAuaWlkOjRDRTFGNUM5NjdBNDExRTE4QkUyRjhCMTI4RjAwMzk4IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjRDRTFGNUNBNjdBNDExRTE4QkUyRjhCMTI4RjAwMzk4Ii8+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+Kta/WAAAARhJREFUeNrs1y2OwlAUgNGW4DEsoOyFEBxhGbOXWQYWhWkQbARTjWMFj/vEiEn4sdyX8yW3Nc/0HtG2L6V00T5mG7PqlKFrzClm7AOw4v3YScp+Z3HZ2UPadhVwYQ9pW8zsIHcAAQqgAAIUQAEUQIACKIACCFAABVAAAQqgAAogQAEUQAEEKIACCFAABVAAAQqgAAogQAEUQAEEKIACKIAABVAABRCgAAqgAAIUQAEEKIACKIAABVAABRCgAAqgAAIUQAHUS8C7NaTtXgEv9pC2yzwuh5h6X8cs7SRFt5gx5tiXUpp5qmmazsMwfDrTxZmNj5jvbFOB3uHVM75CEyK2iNfyb8Q/xFbxak29A590/gNt9QEfAgwAsOgxqt8Lp7QAAAAASUVORK5CYII=";
        };
    };
    jwplayer().registerPlugin('timeslidertooltipplugin.uncompressed', template, "timeslidertooltipplugin-3");
})(jwplayer);