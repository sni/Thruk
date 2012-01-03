/*
 * jQueryMobile-router v0.6
 * http://github.com/azicchetti/jquerymobile-router
 *
 * Copyright 2011 (c) Andrea Zicchetti
 * Dual licensed under the MIT or GPL Version 2 licenses.
 * http://github.com/azicchetti/jquerymobile-router/blob/master/MIT-LICENSE.txt
 * http://github.com/azicchetti/jquerymobile-router/blob/master/GPL-LICENSE.txt
 */
(function($){

$(document).bind("mobileinit",function(){

	/* supports the following configurations:
		$.mobile.jqmRouter.fixFirstPageDataUrl=true
		$.mobile.jqmRouter.firstPageDataUrl="index.html"
			jQM doesn't handle correctly the dataurl of the first page you display
			in a single-page template mode. In fact, the page is fetched again
			from the server the first time you try to access it through a link.
			If this option is set to true, jquery mobile router extensions will
			try to fix this problem. In order to set the data url, you have to
			provide the name of the file containing the first page into the
			"firstPageDataUrl" property (for example: index.html)

	*/

	var config=$.extend({
		fixFirstPageDataUrl: false, firstPageDataUrl: "index.html", ajaxApp: false
	},$.mobile.jqmRouter || {});

	var previousUrl=null, nextUrl=null;

	$(document).bind("pagebeforechange", function( e, data ) {
		// We only want to handle changePage() calls where the caller is
		// asking us to load a page by URL.
		if ( typeof data.toPage === "string" ) {
			// We are being asked to load a page by URL, but we only
			// want to handle URLs that request the data for a specific
			// category.
			var u = $.mobile.path.parseUrl( data.toPage );
			previousUrl=nextUrl;
			nextUrl=u;

			if ( u.hash.indexOf("?") !== -1 ) {
				var page=u.hash.replace( /\?.*$/, "" );
				// We don't want the data-url of the page we just modified
				// to be the url that shows up in the browser's location field,
				// so set the dataUrl option to the URL with hash parameters
				data.options.dataUrl = u.href;
				// Now call changePage() and tell it to switch to
				// the page we just modified, but only in case it's different
				// from the current page
				if (	$.mobile.activePage &&
					page.replace(/^#/,"")==$.mobile.activePage.jqmData("url")
				){
					data.options.allowSamePageTransition=true;
					$.mobile.changePage( $(page), data.options );
				} else {
					$.mobile.changePage( $(page), data.options );
				}
				// Make sure to tell changePage() we've handled this call so it doesn't
				// have to do anything.
				e.preventDefault();
			}
		}
	});


	if (config.fixFirstPageDataUrl){
		$(document).ready(function(){
			var page=$(":jqmData(role='page')").first();
			var	dataUrl=page.jqmData("url"),
				guessedDataUrl=window.location.pathname
					+config.firstPageDataUrl
					+window.location.search
					+window.location.hash
			;
			if (!window.location.pathname.match("/$")){
				return;
			}
			if (dataUrl!=guessedDataUrl){
				page.attr("data-url",guessedDataUrl)
					.jqmData("url",guessedDataUrl);
			}
		});
	}

	$.mobile.Router=function(userRoutes,userHandlers,conf){
		/* userRoutes format:
			{
				"regexp": "function name", // defaults to jqm pagebeforeshow event
				"regexp": function(){ ... }, // defaults to jqm pagebeforeshow event
				"regexp": { handler: "function name", events: "bc,c,bs,s,bh,h"	},
				"regexp": { handler: function(){ ... }, events: "bc,c,bs,s,bh,h" }
			}
		*/
		this.routes={
			pagebeforecreate: null, pagecreate: null,
			pagebeforeshow: null, pageshow: null,
			pagebeforehide: null, pagehide: null,
			pageinit: null, pageremove: null
		};
		this.evtLookup = {
			bc: "pagebeforecreate", c: "pagecreate",
			bs: "pagebeforeshow", s: "pageshow",
			bh: "pagebeforehide", h: "pagehide",
			i: "pageinit", rm: "pageremove"
		};
		this.routesRex={};
		this.conf=$.extend({}, config, conf || {});
		this.defaultHandlerEvents = {};
		if (this.conf.defaultHandlerEvents) {
			var evts = this.conf.defaultHandlerEvents.split(",");
			for (var i = 0; i < evts.length; i++) {
				this.defaultHandlerEvents[this.evtLookup[evts[i]]] = evts[i];
			}
		}
		this.add(userRoutes,userHandlers);
	}
	$.extend($.mobile.Router.prototype,{
		add: function(userRoutes,userHandlers){
			if (!userRoutes) return;

			var _self=this, evtList=[];
			if (userRoutes instanceof Array){
				$.each(userRoutes,$.proxy(function(k,v){
					this.add(v,userHandlers);
				},this));
			} else {
				$.each(userRoutes,function(r,el){
					if(typeof(el)=="string" || typeof(el)=="function"){
						if (_self.routes.pagebeforeshow===null){
							_self.routes.pagebeforeshow={};
						}
						_self.routes.pagebeforeshow[r]=el;
						if (! _self.routesRex.hasOwnProperty(r)){
							_self.routesRex[r]=new RegExp(r);
						}
					} else {
						var i,trig=el.events.split(","),evt;
						for(i in trig){
							evt=_self.evtLookup[trig[i]];
							if (_self.routes.hasOwnProperty(evt)){
								if (_self.routes[evt]===null){
									_self.routes[evt]={};
								}
								_self.routes[evt][r]=el.handler;
								if (! _self.routesRex.hasOwnProperty(r)){
									_self.routesRex[r]=new RegExp(r);
								}
							} else {
								debug("can't set unsupported route "+trig[i]);
							}
						}
					}
				});
				$.each(_self.routes,function(evt,el){
					if (el!==null){
						evtList.push(evt);
					}
				});
				if (!this.userHandlers) this.userHandlers={};
				$.extend(this.userHandlers,userHandlers||{});
				this._detachEvents();
				if (evtList.length>0){
					this._liveData={
						events: evtList.join(" "),
						handler: function(e,ui){ _self._processRoutes(e,ui,this); }
					};
					$(":jqmData(role='page'),:jqmData(role='dialog')").live(
						this._liveData.events, this._liveData.handler
					);
				}
			}
		},

		_processRoutes: function(e,ui,page){
			var _self=this, refUrl, url, $page, retry=0;
			if (e.type in {
				"pagebeforehide":true, "pagehide":true, "pageremove": true
			}){
				refUrl=previousUrl;
			} else {
				refUrl=nextUrl;
			}
			do {
				if (!refUrl){
					if (page){
						$page=$(page);
						refUrl=$page.jqmData("url");
						if (refUrl){
							if ($page.attr("id")==refUrl) refUrl="#"+refUrl;
							refUrl=$.mobile.path.parseUrl(refUrl);
						}
					}
				} else if (page && !$(page).jqmData("url")){
					return;
				}
				if (!refUrl) return;
				url=( !this.conf.ajaxApp ?
					refUrl.hash
					:refUrl.pathname + refUrl.search + refUrl.hash
				);
				if (url.length==0){
					// if ajaxApp is false, url may be "" when the user clicks the back button
					// and returns to the first page of the application (which is usually
					// loaded without the hash part of the url). Let's handle this...
					refUrl="";
				}
				retry++;
			} while(url.length==0 && retry<=1);

			var bHandled = false;
			$.each(this.routes[e.type],function(route,handler){
				var res, handleFn;
				if ( (res=url.match(_self.routesRex[route])) ){
					if (typeof(handler)=="function"){
						handleFn=handler;
					} else if (typeof(_self.userHandlers[handler])=="function"){
						handleFn=_self.userHandlers[handler];
					}
					if (handleFn){
						try { handleFn(e.type,res,ui,page,e); bHandled = true;
						}catch(err){ debug(err); }
					}
				}
			});
			//Pass to default if specified and can handle this event type
			if (!bHandled && this.conf.defaultHandler && this.defaultHandlerEvents[e.type]) {
				if (typeof(this.conf.defaultHandler) == "function") {
					try {
						this.conf.defaultHandler(e.type, ui, page, e);
					} catch(err) { debug(err); }
				}
			}
		},

		_detachEvents: function(){
			if (this._liveData){
				$(":jqmData(role='page'),:jqmData(role='dialog')").die(
					this._liveData.events, this._liveData.handler
				);
			}
		} ,

		destroy: function(){
			this._detachEvents();
			this.routes=this.routesRex=null;
		} ,

		getParams: function(hashparams){
			if (!hashparams) return null;
			var params={}, tmp;
			var tokens=hashparams.slice( hashparams.indexOf('?')+1 ).split("&");
			$.each(tokens,function(k,v){
				tmp=v.split("=");
				if (params[tmp[0]]){
					if (!(params[tmp[0]] instanceof Array)){
						params[tmp[0]]=[ params[tmp[0]] ];
					}
					params[tmp[0]].push(tmp[1]);
				} else {
					params[tmp[0]]=tmp[1];
				}
			});
			if ($.isEmptyObject(params)) return null;
			return params;
		}
	});

});

})(jQuery);
