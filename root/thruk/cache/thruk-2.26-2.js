/*! jQuery v1.12.4 | (c) jQuery Foundation | jquery.org/license */
!function(a,b){"object"==typeof module&&"object"==typeof module.exports?module.exports=a.document?b(a,!0):function(a){if(!a.document)throw new Error("jQuery requires a window with a document");return b(a)}:b(a)}("undefined"!=typeof window?window:this,function(a,b){var c=[],d=a.document,e=c.slice,f=c.concat,g=c.push,h=c.indexOf,i={},j=i.toString,k=i.hasOwnProperty,l={},m="1.12.4",n=function(a,b){return new n.fn.init(a,b)},o=/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g,p=/^-ms-/,q=/-([\da-z])/gi,r=function(a,b){return b.toUpperCase()};n.fn=n.prototype={jquery:m,constructor:n,selector:"",length:0,toArray:function(){return e.call(this)},get:function(a){return null!=a?0>a?this[a+this.length]:this[a]:e.call(this)},pushStack:function(a){var b=n.merge(this.constructor(),a);return b.prevObject=this,b.context=this.context,b},each:function(a){return n.each(this,a)},map:function(a){return this.pushStack(n.map(this,function(b,c){return a.call(b,c,b)}))},slice:function(){return this.pushStack(e.apply(this,arguments))},first:function(){return this.eq(0)},last:function(){return this.eq(-1)},eq:function(a){var b=this.length,c=+a+(0>a?b:0);return this.pushStack(c>=0&&b>c?[this[c]]:[])},end:function(){return this.prevObject||this.constructor()},push:g,sort:c.sort,splice:c.splice},n.extend=n.fn.extend=function(){var a,b,c,d,e,f,g=arguments[0]||{},h=1,i=arguments.length,j=!1;for("boolean"==typeof g&&(j=g,g=arguments[h]||{},h++),"object"==typeof g||n.isFunction(g)||(g={}),h===i&&(g=this,h--);i>h;h++)if(null!=(e=arguments[h]))for(d in e)a=g[d],c=e[d],g!==c&&(j&&c&&(n.isPlainObject(c)||(b=n.isArray(c)))?(b?(b=!1,f=a&&n.isArray(a)?a:[]):f=a&&n.isPlainObject(a)?a:{},g[d]=n.extend(j,f,c)):void 0!==c&&(g[d]=c));return g},n.extend({expando:"jQuery"+(m+Math.random()).replace(/\D/g,""),isReady:!0,error:function(a){throw new Error(a)},noop:function(){},isFunction:function(a){return"function"===n.type(a)},isArray:Array.isArray||function(a){return"array"===n.type(a)},isWindow:function(a){return null!=a&&a==a.window},isNumeric:function(a){var b=a&&a.toString();return!n.isArray(a)&&b-parseFloat(b)+1>=0},isEmptyObject:function(a){var b;for(b in a)return!1;return!0},isPlainObject:function(a){var b;if(!a||"object"!==n.type(a)||a.nodeType||n.isWindow(a))return!1;try{if(a.constructor&&!k.call(a,"constructor")&&!k.call(a.constructor.prototype,"isPrototypeOf"))return!1}catch(c){return!1}if(!l.ownFirst)for(b in a)return k.call(a,b);for(b in a);return void 0===b||k.call(a,b)},type:function(a){return null==a?a+"":"object"==typeof a||"function"==typeof a?i[j.call(a)]||"object":typeof a},globalEval:function(b){b&&n.trim(b)&&(a.execScript||function(b){a.eval.call(a,b)})(b)},camelCase:function(a){return a.replace(p,"ms-").replace(q,r)},nodeName:function(a,b){return a.nodeName&&a.nodeName.toLowerCase()===b.toLowerCase()},each:function(a,b){var c,d=0;if(s(a)){for(c=a.length;c>d;d++)if(b.call(a[d],d,a[d])===!1)break}else for(d in a)if(b.call(a[d],d,a[d])===!1)break;return a},trim:function(a){return null==a?"":(a+"").replace(o,"")},makeArray:function(a,b){var c=b||[];return null!=a&&(s(Object(a))?n.merge(c,"string"==typeof a?[a]:a):g.call(c,a)),c},inArray:function(a,b,c){var d;if(b){if(h)return h.call(b,a,c);for(d=b.length,c=c?0>c?Math.max(0,d+c):c:0;d>c;c++)if(c in b&&b[c]===a)return c}return-1},merge:function(a,b){var c=+b.length,d=0,e=a.length;while(c>d)a[e++]=b[d++];if(c!==c)while(void 0!==b[d])a[e++]=b[d++];return a.length=e,a},grep:function(a,b,c){for(var d,e=[],f=0,g=a.length,h=!c;g>f;f++)d=!b(a[f],f),d!==h&&e.push(a[f]);return e},map:function(a,b,c){var d,e,g=0,h=[];if(s(a))for(d=a.length;d>g;g++)e=b(a[g],g,c),null!=e&&h.push(e);else for(g in a)e=b(a[g],g,c),null!=e&&h.push(e);return f.apply([],h)},guid:1,proxy:function(a,b){var c,d,f;return"string"==typeof b&&(f=a[b],b=a,a=f),n.isFunction(a)?(c=e.call(arguments,2),d=function(){return a.apply(b||this,c.concat(e.call(arguments)))},d.guid=a.guid=a.guid||n.guid++,d):void 0},now:function(){return+new Date},support:l}),"function"==typeof Symbol&&(n.fn[Symbol.iterator]=c[Symbol.iterator]),n.each("Boolean Number String Function Array Date RegExp Object Error Symbol".split(" "),function(a,b){i["[object "+b+"]"]=b.toLowerCase()});function s(a){var b=!!a&&"length"in a&&a.length,c=n.type(a);return"function"===c||n.isWindow(a)?!1:"array"===c||0===b||"number"==typeof b&&b>0&&b-1 in a}var t=function(a){var b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u="sizzle"+1*new Date,v=a.document,w=0,x=0,y=ga(),z=ga(),A=ga(),B=function(a,b){return a===b&&(l=!0),0},C=1<<31,D={}.hasOwnProperty,E=[],F=E.pop,G=E.push,H=E.push,I=E.slice,J=function(a,b){for(var c=0,d=a.length;d>c;c++)if(a[c]===b)return c;return-1},K="checked|selected|async|autofocus|autoplay|controls|defer|disabled|hidden|ismap|loop|multiple|open|readonly|required|scoped",L="[\\x20\\t\\r\\n\\f]",M="(?:\\\\.|[\\w-]|[^\\x00-\\xa0])+",N="\\["+L+"*("+M+")(?:"+L+"*([*^$|!~]?=)"+L+"*(?:'((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\"|("+M+"))|)"+L+"*\\]",O=":("+M+")(?:\\((('((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\")|((?:\\\\.|[^\\\\()[\\]]|"+N+")*)|.*)\\)|)",P=new RegExp(L+"+","g"),Q=new RegExp("^"+L+"+|((?:^|[^\\\\])(?:\\\\.)*)"+L+"+$","g"),R=new RegExp("^"+L+"*,"+L+"*"),S=new RegExp("^"+L+"*([>+~]|"+L+")"+L+"*"),T=new RegExp("="+L+"*([^\\]'\"]*?)"+L+"*\\]","g"),U=new RegExp(O),V=new RegExp("^"+M+"$"),W={ID:new RegExp("^#("+M+")"),CLASS:new RegExp("^\\.("+M+")"),TAG:new RegExp("^("+M+"|[*])"),ATTR:new RegExp("^"+N),PSEUDO:new RegExp("^"+O),CHILD:new RegExp("^:(only|first|last|nth|nth-last)-(child|of-type)(?:\\("+L+"*(even|odd|(([+-]|)(\\d*)n|)"+L+"*(?:([+-]|)"+L+"*(\\d+)|))"+L+"*\\)|)","i"),bool:new RegExp("^(?:"+K+")$","i"),needsContext:new RegExp("^"+L+"*[>+~]|:(even|odd|eq|gt|lt|nth|first|last)(?:\\("+L+"*((?:-\\d)?\\d*)"+L+"*\\)|)(?=[^-]|$)","i")},X=/^(?:input|select|textarea|button)$/i,Y=/^h\d$/i,Z=/^[^{]+\{\s*\[native \w/,$=/^(?:#([\w-]+)|(\w+)|\.([\w-]+))$/,_=/[+~]/,aa=/'|\\/g,ba=new RegExp("\\\\([\\da-f]{1,6}"+L+"?|("+L+")|.)","ig"),ca=function(a,b,c){var d="0x"+b-65536;return d!==d||c?b:0>d?String.fromCharCode(d+65536):String.fromCharCode(d>>10|55296,1023&d|56320)},da=function(){m()};try{H.apply(E=I.call(v.childNodes),v.childNodes),E[v.childNodes.length].nodeType}catch(ea){H={apply:E.length?function(a,b){G.apply(a,I.call(b))}:function(a,b){var c=a.length,d=0;while(a[c++]=b[d++]);a.length=c-1}}}function fa(a,b,d,e){var f,h,j,k,l,o,r,s,w=b&&b.ownerDocument,x=b?b.nodeType:9;if(d=d||[],"string"!=typeof a||!a||1!==x&&9!==x&&11!==x)return d;if(!e&&((b?b.ownerDocument||b:v)!==n&&m(b),b=b||n,p)){if(11!==x&&(o=$.exec(a)))if(f=o[1]){if(9===x){if(!(j=b.getElementById(f)))return d;if(j.id===f)return d.push(j),d}else if(w&&(j=w.getElementById(f))&&t(b,j)&&j.id===f)return d.push(j),d}else{if(o[2])return H.apply(d,b.getElementsByTagName(a)),d;if((f=o[3])&&c.getElementsByClassName&&b.getElementsByClassName)return H.apply(d,b.getElementsByClassName(f)),d}if(c.qsa&&!A[a+" "]&&(!q||!q.test(a))){if(1!==x)w=b,s=a;else if("object"!==b.nodeName.toLowerCase()){(k=b.getAttribute("id"))?k=k.replace(aa,"\\$&"):b.setAttribute("id",k=u),r=g(a),h=r.length,l=V.test(k)?"#"+k:"[id='"+k+"']";while(h--)r[h]=l+" "+qa(r[h]);s=r.join(","),w=_.test(a)&&oa(b.parentNode)||b}if(s)try{return H.apply(d,w.querySelectorAll(s)),d}catch(y){}finally{k===u&&b.removeAttribute("id")}}}return i(a.replace(Q,"$1"),b,d,e)}function ga(){var a=[];function b(c,e){return a.push(c+" ")>d.cacheLength&&delete b[a.shift()],b[c+" "]=e}return b}function ha(a){return a[u]=!0,a}function ia(a){var b=n.createElement("div");try{return!!a(b)}catch(c){return!1}finally{b.parentNode&&b.parentNode.removeChild(b),b=null}}function ja(a,b){var c=a.split("|"),e=c.length;while(e--)d.attrHandle[c[e]]=b}function ka(a,b){var c=b&&a,d=c&&1===a.nodeType&&1===b.nodeType&&(~b.sourceIndex||C)-(~a.sourceIndex||C);if(d)return d;if(c)while(c=c.nextSibling)if(c===b)return-1;return a?1:-1}function la(a){return function(b){var c=b.nodeName.toLowerCase();return"input"===c&&b.type===a}}function ma(a){return function(b){var c=b.nodeName.toLowerCase();return("input"===c||"button"===c)&&b.type===a}}function na(a){return ha(function(b){return b=+b,ha(function(c,d){var e,f=a([],c.length,b),g=f.length;while(g--)c[e=f[g]]&&(c[e]=!(d[e]=c[e]))})})}function oa(a){return a&&"undefined"!=typeof a.getElementsByTagName&&a}c=fa.support={},f=fa.isXML=function(a){var b=a&&(a.ownerDocument||a).documentElement;return b?"HTML"!==b.nodeName:!1},m=fa.setDocument=function(a){var b,e,g=a?a.ownerDocument||a:v;return g!==n&&9===g.nodeType&&g.documentElement?(n=g,o=n.documentElement,p=!f(n),(e=n.defaultView)&&e.top!==e&&(e.addEventListener?e.addEventListener("unload",da,!1):e.attachEvent&&e.attachEvent("onunload",da)),c.attributes=ia(function(a){return a.className="i",!a.getAttribute("className")}),c.getElementsByTagName=ia(function(a){return a.appendChild(n.createComment("")),!a.getElementsByTagName("*").length}),c.getElementsByClassName=Z.test(n.getElementsByClassName),c.getById=ia(function(a){return o.appendChild(a).id=u,!n.getElementsByName||!n.getElementsByName(u).length}),c.getById?(d.find.ID=function(a,b){if("undefined"!=typeof b.getElementById&&p){var c=b.getElementById(a);return c?[c]:[]}},d.filter.ID=function(a){var b=a.replace(ba,ca);return function(a){return a.getAttribute("id")===b}}):(delete d.find.ID,d.filter.ID=function(a){var b=a.replace(ba,ca);return function(a){var c="undefined"!=typeof a.getAttributeNode&&a.getAttributeNode("id");return c&&c.value===b}}),d.find.TAG=c.getElementsByTagName?function(a,b){return"undefined"!=typeof b.getElementsByTagName?b.getElementsByTagName(a):c.qsa?b.querySelectorAll(a):void 0}:function(a,b){var c,d=[],e=0,f=b.getElementsByTagName(a);if("*"===a){while(c=f[e++])1===c.nodeType&&d.push(c);return d}return f},d.find.CLASS=c.getElementsByClassName&&function(a,b){return"undefined"!=typeof b.getElementsByClassName&&p?b.getElementsByClassName(a):void 0},r=[],q=[],(c.qsa=Z.test(n.querySelectorAll))&&(ia(function(a){o.appendChild(a).innerHTML="<a id='"+u+"'></a><select id='"+u+"-\r\\' msallowcapture=''><option selected=''></option></select>",a.querySelectorAll("[msallowcapture^='']").length&&q.push("[*^$]="+L+"*(?:''|\"\")"),a.querySelectorAll("[selected]").length||q.push("\\["+L+"*(?:value|"+K+")"),a.querySelectorAll("[id~="+u+"-]").length||q.push("~="),a.querySelectorAll(":checked").length||q.push(":checked"),a.querySelectorAll("a#"+u+"+*").length||q.push(".#.+[+~]")}),ia(function(a){var b=n.createElement("input");b.setAttribute("type","hidden"),a.appendChild(b).setAttribute("name","D"),a.querySelectorAll("[name=d]").length&&q.push("name"+L+"*[*^$|!~]?="),a.querySelectorAll(":enabled").length||q.push(":enabled",":disabled"),a.querySelectorAll("*,:x"),q.push(",.*:")})),(c.matchesSelector=Z.test(s=o.matches||o.webkitMatchesSelector||o.mozMatchesSelector||o.oMatchesSelector||o.msMatchesSelector))&&ia(function(a){c.disconnectedMatch=s.call(a,"div"),s.call(a,"[s!='']:x"),r.push("!=",O)}),q=q.length&&new RegExp(q.join("|")),r=r.length&&new RegExp(r.join("|")),b=Z.test(o.compareDocumentPosition),t=b||Z.test(o.contains)?function(a,b){var c=9===a.nodeType?a.documentElement:a,d=b&&b.parentNode;return a===d||!(!d||1!==d.nodeType||!(c.contains?c.contains(d):a.compareDocumentPosition&&16&a.compareDocumentPosition(d)))}:function(a,b){if(b)while(b=b.parentNode)if(b===a)return!0;return!1},B=b?function(a,b){if(a===b)return l=!0,0;var d=!a.compareDocumentPosition-!b.compareDocumentPosition;return d?d:(d=(a.ownerDocument||a)===(b.ownerDocument||b)?a.compareDocumentPosition(b):1,1&d||!c.sortDetached&&b.compareDocumentPosition(a)===d?a===n||a.ownerDocument===v&&t(v,a)?-1:b===n||b.ownerDocument===v&&t(v,b)?1:k?J(k,a)-J(k,b):0:4&d?-1:1)}:function(a,b){if(a===b)return l=!0,0;var c,d=0,e=a.parentNode,f=b.parentNode,g=[a],h=[b];if(!e||!f)return a===n?-1:b===n?1:e?-1:f?1:k?J(k,a)-J(k,b):0;if(e===f)return ka(a,b);c=a;while(c=c.parentNode)g.unshift(c);c=b;while(c=c.parentNode)h.unshift(c);while(g[d]===h[d])d++;return d?ka(g[d],h[d]):g[d]===v?-1:h[d]===v?1:0},n):n},fa.matches=function(a,b){return fa(a,null,null,b)},fa.matchesSelector=function(a,b){if((a.ownerDocument||a)!==n&&m(a),b=b.replace(T,"='$1']"),c.matchesSelector&&p&&!A[b+" "]&&(!r||!r.test(b))&&(!q||!q.test(b)))try{var d=s.call(a,b);if(d||c.disconnectedMatch||a.document&&11!==a.document.nodeType)return d}catch(e){}return fa(b,n,null,[a]).length>0},fa.contains=function(a,b){return(a.ownerDocument||a)!==n&&m(a),t(a,b)},fa.attr=function(a,b){(a.ownerDocument||a)!==n&&m(a);var e=d.attrHandle[b.toLowerCase()],f=e&&D.call(d.attrHandle,b.toLowerCase())?e(a,b,!p):void 0;return void 0!==f?f:c.attributes||!p?a.getAttribute(b):(f=a.getAttributeNode(b))&&f.specified?f.value:null},fa.error=function(a){throw new Error("Syntax error, unrecognized expression: "+a)},fa.uniqueSort=function(a){var b,d=[],e=0,f=0;if(l=!c.detectDuplicates,k=!c.sortStable&&a.slice(0),a.sort(B),l){while(b=a[f++])b===a[f]&&(e=d.push(f));while(e--)a.splice(d[e],1)}return k=null,a},e=fa.getText=function(a){var b,c="",d=0,f=a.nodeType;if(f){if(1===f||9===f||11===f){if("string"==typeof a.textContent)return a.textContent;for(a=a.firstChild;a;a=a.nextSibling)c+=e(a)}else if(3===f||4===f)return a.nodeValue}else while(b=a[d++])c+=e(b);return c},d=fa.selectors={cacheLength:50,createPseudo:ha,match:W,attrHandle:{},find:{},relative:{">":{dir:"parentNode",first:!0}," ":{dir:"parentNode"},"+":{dir:"previousSibling",first:!0},"~":{dir:"previousSibling"}},preFilter:{ATTR:function(a){return a[1]=a[1].replace(ba,ca),a[3]=(a[3]||a[4]||a[5]||"").replace(ba,ca),"~="===a[2]&&(a[3]=" "+a[3]+" "),a.slice(0,4)},CHILD:function(a){return a[1]=a[1].toLowerCase(),"nth"===a[1].slice(0,3)?(a[3]||fa.error(a[0]),a[4]=+(a[4]?a[5]+(a[6]||1):2*("even"===a[3]||"odd"===a[3])),a[5]=+(a[7]+a[8]||"odd"===a[3])):a[3]&&fa.error(a[0]),a},PSEUDO:function(a){var b,c=!a[6]&&a[2];return W.CHILD.test(a[0])?null:(a[3]?a[2]=a[4]||a[5]||"":c&&U.test(c)&&(b=g(c,!0))&&(b=c.indexOf(")",c.length-b)-c.length)&&(a[0]=a[0].slice(0,b),a[2]=c.slice(0,b)),a.slice(0,3))}},filter:{TAG:function(a){var b=a.replace(ba,ca).toLowerCase();return"*"===a?function(){return!0}:function(a){return a.nodeName&&a.nodeName.toLowerCase()===b}},CLASS:function(a){var b=y[a+" "];return b||(b=new RegExp("(^|"+L+")"+a+"("+L+"|$)"))&&y(a,function(a){return b.test("string"==typeof a.className&&a.className||"undefined"!=typeof a.getAttribute&&a.getAttribute("class")||"")})},ATTR:function(a,b,c){return function(d){var e=fa.attr(d,a);return null==e?"!="===b:b?(e+="","="===b?e===c:"!="===b?e!==c:"^="===b?c&&0===e.indexOf(c):"*="===b?c&&e.indexOf(c)>-1:"$="===b?c&&e.slice(-c.length)===c:"~="===b?(" "+e.replace(P," ")+" ").indexOf(c)>-1:"|="===b?e===c||e.slice(0,c.length+1)===c+"-":!1):!0}},CHILD:function(a,b,c,d,e){var f="nth"!==a.slice(0,3),g="last"!==a.slice(-4),h="of-type"===b;return 1===d&&0===e?function(a){return!!a.parentNode}:function(b,c,i){var j,k,l,m,n,o,p=f!==g?"nextSibling":"previousSibling",q=b.parentNode,r=h&&b.nodeName.toLowerCase(),s=!i&&!h,t=!1;if(q){if(f){while(p){m=b;while(m=m[p])if(h?m.nodeName.toLowerCase()===r:1===m.nodeType)return!1;o=p="only"===a&&!o&&"nextSibling"}return!0}if(o=[g?q.firstChild:q.lastChild],g&&s){m=q,l=m[u]||(m[u]={}),k=l[m.uniqueID]||(l[m.uniqueID]={}),j=k[a]||[],n=j[0]===w&&j[1],t=n&&j[2],m=n&&q.childNodes[n];while(m=++n&&m&&m[p]||(t=n=0)||o.pop())if(1===m.nodeType&&++t&&m===b){k[a]=[w,n,t];break}}else if(s&&(m=b,l=m[u]||(m[u]={}),k=l[m.uniqueID]||(l[m.uniqueID]={}),j=k[a]||[],n=j[0]===w&&j[1],t=n),t===!1)while(m=++n&&m&&m[p]||(t=n=0)||o.pop())if((h?m.nodeName.toLowerCase()===r:1===m.nodeType)&&++t&&(s&&(l=m[u]||(m[u]={}),k=l[m.uniqueID]||(l[m.uniqueID]={}),k[a]=[w,t]),m===b))break;return t-=e,t===d||t%d===0&&t/d>=0}}},PSEUDO:function(a,b){var c,e=d.pseudos[a]||d.setFilters[a.toLowerCase()]||fa.error("unsupported pseudo: "+a);return e[u]?e(b):e.length>1?(c=[a,a,"",b],d.setFilters.hasOwnProperty(a.toLowerCase())?ha(function(a,c){var d,f=e(a,b),g=f.length;while(g--)d=J(a,f[g]),a[d]=!(c[d]=f[g])}):function(a){return e(a,0,c)}):e}},pseudos:{not:ha(function(a){var b=[],c=[],d=h(a.replace(Q,"$1"));return d[u]?ha(function(a,b,c,e){var f,g=d(a,null,e,[]),h=a.length;while(h--)(f=g[h])&&(a[h]=!(b[h]=f))}):function(a,e,f){return b[0]=a,d(b,null,f,c),b[0]=null,!c.pop()}}),has:ha(function(a){return function(b){return fa(a,b).length>0}}),contains:ha(function(a){return a=a.replace(ba,ca),function(b){return(b.textContent||b.innerText||e(b)).indexOf(a)>-1}}),lang:ha(function(a){return V.test(a||"")||fa.error("unsupported lang: "+a),a=a.replace(ba,ca).toLowerCase(),function(b){var c;do if(c=p?b.lang:b.getAttribute("xml:lang")||b.getAttribute("lang"))return c=c.toLowerCase(),c===a||0===c.indexOf(a+"-");while((b=b.parentNode)&&1===b.nodeType);return!1}}),target:function(b){var c=a.location&&a.location.hash;return c&&c.slice(1)===b.id},root:function(a){return a===o},focus:function(a){return a===n.activeElement&&(!n.hasFocus||n.hasFocus())&&!!(a.type||a.href||~a.tabIndex)},enabled:function(a){return a.disabled===!1},disabled:function(a){return a.disabled===!0},checked:function(a){var b=a.nodeName.toLowerCase();return"input"===b&&!!a.checked||"option"===b&&!!a.selected},selected:function(a){return a.parentNode&&a.parentNode.selectedIndex,a.selected===!0},empty:function(a){for(a=a.firstChild;a;a=a.nextSibling)if(a.nodeType<6)return!1;return!0},parent:function(a){return!d.pseudos.empty(a)},header:function(a){return Y.test(a.nodeName)},input:function(a){return X.test(a.nodeName)},button:function(a){var b=a.nodeName.toLowerCase();return"input"===b&&"button"===a.type||"button"===b},text:function(a){var b;return"input"===a.nodeName.toLowerCase()&&"text"===a.type&&(null==(b=a.getAttribute("type"))||"text"===b.toLowerCase())},first:na(function(){return[0]}),last:na(function(a,b){return[b-1]}),eq:na(function(a,b,c){return[0>c?c+b:c]}),even:na(function(a,b){for(var c=0;b>c;c+=2)a.push(c);return a}),odd:na(function(a,b){for(var c=1;b>c;c+=2)a.push(c);return a}),lt:na(function(a,b,c){for(var d=0>c?c+b:c;--d>=0;)a.push(d);return a}),gt:na(function(a,b,c){for(var d=0>c?c+b:c;++d<b;)a.push(d);return a})}},d.pseudos.nth=d.pseudos.eq;for(b in{radio:!0,checkbox:!0,file:!0,password:!0,image:!0})d.pseudos[b]=la(b);for(b in{submit:!0,reset:!0})d.pseudos[b]=ma(b);function pa(){}pa.prototype=d.filters=d.pseudos,d.setFilters=new pa,g=fa.tokenize=function(a,b){var c,e,f,g,h,i,j,k=z[a+" "];if(k)return b?0:k.slice(0);h=a,i=[],j=d.preFilter;while(h){c&&!(e=R.exec(h))||(e&&(h=h.slice(e[0].length)||h),i.push(f=[])),c=!1,(e=S.exec(h))&&(c=e.shift(),f.push({value:c,type:e[0].replace(Q," ")}),h=h.slice(c.length));for(g in d.filter)!(e=W[g].exec(h))||j[g]&&!(e=j[g](e))||(c=e.shift(),f.push({value:c,type:g,matches:e}),h=h.slice(c.length));if(!c)break}return b?h.length:h?fa.error(a):z(a,i).slice(0)};function qa(a){for(var b=0,c=a.length,d="";c>b;b++)d+=a[b].value;return d}function ra(a,b,c){var d=b.dir,e=c&&"parentNode"===d,f=x++;return b.first?function(b,c,f){while(b=b[d])if(1===b.nodeType||e)return a(b,c,f)}:function(b,c,g){var h,i,j,k=[w,f];if(g){while(b=b[d])if((1===b.nodeType||e)&&a(b,c,g))return!0}else while(b=b[d])if(1===b.nodeType||e){if(j=b[u]||(b[u]={}),i=j[b.uniqueID]||(j[b.uniqueID]={}),(h=i[d])&&h[0]===w&&h[1]===f)return k[2]=h[2];if(i[d]=k,k[2]=a(b,c,g))return!0}}}function sa(a){return a.length>1?function(b,c,d){var e=a.length;while(e--)if(!a[e](b,c,d))return!1;return!0}:a[0]}function ta(a,b,c){for(var d=0,e=b.length;e>d;d++)fa(a,b[d],c);return c}function ua(a,b,c,d,e){for(var f,g=[],h=0,i=a.length,j=null!=b;i>h;h++)(f=a[h])&&(c&&!c(f,d,e)||(g.push(f),j&&b.push(h)));return g}function va(a,b,c,d,e,f){return d&&!d[u]&&(d=va(d)),e&&!e[u]&&(e=va(e,f)),ha(function(f,g,h,i){var j,k,l,m=[],n=[],o=g.length,p=f||ta(b||"*",h.nodeType?[h]:h,[]),q=!a||!f&&b?p:ua(p,m,a,h,i),r=c?e||(f?a:o||d)?[]:g:q;if(c&&c(q,r,h,i),d){j=ua(r,n),d(j,[],h,i),k=j.length;while(k--)(l=j[k])&&(r[n[k]]=!(q[n[k]]=l))}if(f){if(e||a){if(e){j=[],k=r.length;while(k--)(l=r[k])&&j.push(q[k]=l);e(null,r=[],j,i)}k=r.length;while(k--)(l=r[k])&&(j=e?J(f,l):m[k])>-1&&(f[j]=!(g[j]=l))}}else r=ua(r===g?r.splice(o,r.length):r),e?e(null,g,r,i):H.apply(g,r)})}function wa(a){for(var b,c,e,f=a.length,g=d.relative[a[0].type],h=g||d.relative[" "],i=g?1:0,k=ra(function(a){return a===b},h,!0),l=ra(function(a){return J(b,a)>-1},h,!0),m=[function(a,c,d){var e=!g&&(d||c!==j)||((b=c).nodeType?k(a,c,d):l(a,c,d));return b=null,e}];f>i;i++)if(c=d.relative[a[i].type])m=[ra(sa(m),c)];else{if(c=d.filter[a[i].type].apply(null,a[i].matches),c[u]){for(e=++i;f>e;e++)if(d.relative[a[e].type])break;return va(i>1&&sa(m),i>1&&qa(a.slice(0,i-1).concat({value:" "===a[i-2].type?"*":""})).replace(Q,"$1"),c,e>i&&wa(a.slice(i,e)),f>e&&wa(a=a.slice(e)),f>e&&qa(a))}m.push(c)}return sa(m)}function xa(a,b){var c=b.length>0,e=a.length>0,f=function(f,g,h,i,k){var l,o,q,r=0,s="0",t=f&&[],u=[],v=j,x=f||e&&d.find.TAG("*",k),y=w+=null==v?1:Math.random()||.1,z=x.length;for(k&&(j=g===n||g||k);s!==z&&null!=(l=x[s]);s++){if(e&&l){o=0,g||l.ownerDocument===n||(m(l),h=!p);while(q=a[o++])if(q(l,g||n,h)){i.push(l);break}k&&(w=y)}c&&((l=!q&&l)&&r--,f&&t.push(l))}if(r+=s,c&&s!==r){o=0;while(q=b[o++])q(t,u,g,h);if(f){if(r>0)while(s--)t[s]||u[s]||(u[s]=F.call(i));u=ua(u)}H.apply(i,u),k&&!f&&u.length>0&&r+b.length>1&&fa.uniqueSort(i)}return k&&(w=y,j=v),t};return c?ha(f):f}return h=fa.compile=function(a,b){var c,d=[],e=[],f=A[a+" "];if(!f){b||(b=g(a)),c=b.length;while(c--)f=wa(b[c]),f[u]?d.push(f):e.push(f);f=A(a,xa(e,d)),f.selector=a}return f},i=fa.select=function(a,b,e,f){var i,j,k,l,m,n="function"==typeof a&&a,o=!f&&g(a=n.selector||a);if(e=e||[],1===o.length){if(j=o[0]=o[0].slice(0),j.length>2&&"ID"===(k=j[0]).type&&c.getById&&9===b.nodeType&&p&&d.relative[j[1].type]){if(b=(d.find.ID(k.matches[0].replace(ba,ca),b)||[])[0],!b)return e;n&&(b=b.parentNode),a=a.slice(j.shift().value.length)}i=W.needsContext.test(a)?0:j.length;while(i--){if(k=j[i],d.relative[l=k.type])break;if((m=d.find[l])&&(f=m(k.matches[0].replace(ba,ca),_.test(j[0].type)&&oa(b.parentNode)||b))){if(j.splice(i,1),a=f.length&&qa(j),!a)return H.apply(e,f),e;break}}}return(n||h(a,o))(f,b,!p,e,!b||_.test(a)&&oa(b.parentNode)||b),e},c.sortStable=u.split("").sort(B).join("")===u,c.detectDuplicates=!!l,m(),c.sortDetached=ia(function(a){return 1&a.compareDocumentPosition(n.createElement("div"))}),ia(function(a){return a.innerHTML="<a href='#'></a>","#"===a.firstChild.getAttribute("href")})||ja("type|href|height|width",function(a,b,c){return c?void 0:a.getAttribute(b,"type"===b.toLowerCase()?1:2)}),c.attributes&&ia(function(a){return a.innerHTML="<input/>",a.firstChild.setAttribute("value",""),""===a.firstChild.getAttribute("value")})||ja("value",function(a,b,c){return c||"input"!==a.nodeName.toLowerCase()?void 0:a.defaultValue}),ia(function(a){return null==a.getAttribute("disabled")})||ja(K,function(a,b,c){var d;return c?void 0:a[b]===!0?b.toLowerCase():(d=a.getAttributeNode(b))&&d.specified?d.value:null}),fa}(a);n.find=t,n.expr=t.selectors,n.expr[":"]=n.expr.pseudos,n.uniqueSort=n.unique=t.uniqueSort,n.text=t.getText,n.isXMLDoc=t.isXML,n.contains=t.contains;var u=function(a,b,c){var d=[],e=void 0!==c;while((a=a[b])&&9!==a.nodeType)if(1===a.nodeType){if(e&&n(a).is(c))break;d.push(a)}return d},v=function(a,b){for(var c=[];a;a=a.nextSibling)1===a.nodeType&&a!==b&&c.push(a);return c},w=n.expr.match.needsContext,x=/^<([\w-]+)\s*\/?>(?:<\/\1>|)$/,y=/^.[^:#\[\.,]*$/;function z(a,b,c){if(n.isFunction(b))return n.grep(a,function(a,d){return!!b.call(a,d,a)!==c});if(b.nodeType)return n.grep(a,function(a){return a===b!==c});if("string"==typeof b){if(y.test(b))return n.filter(b,a,c);b=n.filter(b,a)}return n.grep(a,function(a){return n.inArray(a,b)>-1!==c})}n.filter=function(a,b,c){var d=b[0];return c&&(a=":not("+a+")"),1===b.length&&1===d.nodeType?n.find.matchesSelector(d,a)?[d]:[]:n.find.matches(a,n.grep(b,function(a){return 1===a.nodeType}))},n.fn.extend({find:function(a){var b,c=[],d=this,e=d.length;if("string"!=typeof a)return this.pushStack(n(a).filter(function(){for(b=0;e>b;b++)if(n.contains(d[b],this))return!0}));for(b=0;e>b;b++)n.find(a,d[b],c);return c=this.pushStack(e>1?n.unique(c):c),c.selector=this.selector?this.selector+" "+a:a,c},filter:function(a){return this.pushStack(z(this,a||[],!1))},not:function(a){return this.pushStack(z(this,a||[],!0))},is:function(a){return!!z(this,"string"==typeof a&&w.test(a)?n(a):a||[],!1).length}});var A,B=/^(?:\s*(<[\w\W]+>)[^>]*|#([\w-]*))$/,C=n.fn.init=function(a,b,c){var e,f;if(!a)return this;if(c=c||A,"string"==typeof a){if(e="<"===a.charAt(0)&&">"===a.charAt(a.length-1)&&a.length>=3?[null,a,null]:B.exec(a),!e||!e[1]&&b)return!b||b.jquery?(b||c).find(a):this.constructor(b).find(a);if(e[1]){if(b=b instanceof n?b[0]:b,n.merge(this,n.parseHTML(e[1],b&&b.nodeType?b.ownerDocument||b:d,!0)),x.test(e[1])&&n.isPlainObject(b))for(e in b)n.isFunction(this[e])?this[e](b[e]):this.attr(e,b[e]);return this}if(f=d.getElementById(e[2]),f&&f.parentNode){if(f.id!==e[2])return A.find(a);this.length=1,this[0]=f}return this.context=d,this.selector=a,this}return a.nodeType?(this.context=this[0]=a,this.length=1,this):n.isFunction(a)?"undefined"!=typeof c.ready?c.ready(a):a(n):(void 0!==a.selector&&(this.selector=a.selector,this.context=a.context),n.makeArray(a,this))};C.prototype=n.fn,A=n(d);var D=/^(?:parents|prev(?:Until|All))/,E={children:!0,contents:!0,next:!0,prev:!0};n.fn.extend({has:function(a){var b,c=n(a,this),d=c.length;return this.filter(function(){for(b=0;d>b;b++)if(n.contains(this,c[b]))return!0})},closest:function(a,b){for(var c,d=0,e=this.length,f=[],g=w.test(a)||"string"!=typeof a?n(a,b||this.context):0;e>d;d++)for(c=this[d];c&&c!==b;c=c.parentNode)if(c.nodeType<11&&(g?g.index(c)>-1:1===c.nodeType&&n.find.matchesSelector(c,a))){f.push(c);break}return this.pushStack(f.length>1?n.uniqueSort(f):f)},index:function(a){return a?"string"==typeof a?n.inArray(this[0],n(a)):n.inArray(a.jquery?a[0]:a,this):this[0]&&this[0].parentNode?this.first().prevAll().length:-1},add:function(a,b){return this.pushStack(n.uniqueSort(n.merge(this.get(),n(a,b))))},addBack:function(a){return this.add(null==a?this.prevObject:this.prevObject.filter(a))}});function F(a,b){do a=a[b];while(a&&1!==a.nodeType);return a}n.each({parent:function(a){var b=a.parentNode;return b&&11!==b.nodeType?b:null},parents:function(a){return u(a,"parentNode")},parentsUntil:function(a,b,c){return u(a,"parentNode",c)},next:function(a){return F(a,"nextSibling")},prev:function(a){return F(a,"previousSibling")},nextAll:function(a){return u(a,"nextSibling")},prevAll:function(a){return u(a,"previousSibling")},nextUntil:function(a,b,c){return u(a,"nextSibling",c)},prevUntil:function(a,b,c){return u(a,"previousSibling",c)},siblings:function(a){return v((a.parentNode||{}).firstChild,a)},children:function(a){return v(a.firstChild)},contents:function(a){return n.nodeName(a,"iframe")?a.contentDocument||a.contentWindow.document:n.merge([],a.childNodes)}},function(a,b){n.fn[a]=function(c,d){var e=n.map(this,b,c);return"Until"!==a.slice(-5)&&(d=c),d&&"string"==typeof d&&(e=n.filter(d,e)),this.length>1&&(E[a]||(e=n.uniqueSort(e)),D.test(a)&&(e=e.reverse())),this.pushStack(e)}});var G=/\S+/g;function H(a){var b={};return n.each(a.match(G)||[],function(a,c){b[c]=!0}),b}n.Callbacks=function(a){a="string"==typeof a?H(a):n.extend({},a);var b,c,d,e,f=[],g=[],h=-1,i=function(){for(e=a.once,d=b=!0;g.length;h=-1){c=g.shift();while(++h<f.length)f[h].apply(c[0],c[1])===!1&&a.stopOnFalse&&(h=f.length,c=!1)}a.memory||(c=!1),b=!1,e&&(f=c?[]:"")},j={add:function(){return f&&(c&&!b&&(h=f.length-1,g.push(c)),function d(b){n.each(b,function(b,c){n.isFunction(c)?a.unique&&j.has(c)||f.push(c):c&&c.length&&"string"!==n.type(c)&&d(c)})}(arguments),c&&!b&&i()),this},remove:function(){return n.each(arguments,function(a,b){var c;while((c=n.inArray(b,f,c))>-1)f.splice(c,1),h>=c&&h--}),this},has:function(a){return a?n.inArray(a,f)>-1:f.length>0},empty:function(){return f&&(f=[]),this},disable:function(){return e=g=[],f=c="",this},disabled:function(){return!f},lock:function(){return e=!0,c||j.disable(),this},locked:function(){return!!e},fireWith:function(a,c){return e||(c=c||[],c=[a,c.slice?c.slice():c],g.push(c),b||i()),this},fire:function(){return j.fireWith(this,arguments),this},fired:function(){return!!d}};return j},n.extend({Deferred:function(a){var b=[["resolve","done",n.Callbacks("once memory"),"resolved"],["reject","fail",n.Callbacks("once memory"),"rejected"],["notify","progress",n.Callbacks("memory")]],c="pending",d={state:function(){return c},always:function(){return e.done(arguments).fail(arguments),this},then:function(){var a=arguments;return n.Deferred(function(c){n.each(b,function(b,f){var g=n.isFunction(a[b])&&a[b];e[f[1]](function(){var a=g&&g.apply(this,arguments);a&&n.isFunction(a.promise)?a.promise().progress(c.notify).done(c.resolve).fail(c.reject):c[f[0]+"With"](this===d?c.promise():this,g?[a]:arguments)})}),a=null}).promise()},promise:function(a){return null!=a?n.extend(a,d):d}},e={};return d.pipe=d.then,n.each(b,function(a,f){var g=f[2],h=f[3];d[f[1]]=g.add,h&&g.add(function(){c=h},b[1^a][2].disable,b[2][2].lock),e[f[0]]=function(){return e[f[0]+"With"](this===e?d:this,arguments),this},e[f[0]+"With"]=g.fireWith}),d.promise(e),a&&a.call(e,e),e},when:function(a){var b=0,c=e.call(arguments),d=c.length,f=1!==d||a&&n.isFunction(a.promise)?d:0,g=1===f?a:n.Deferred(),h=function(a,b,c){return function(d){b[a]=this,c[a]=arguments.length>1?e.call(arguments):d,c===i?g.notifyWith(b,c):--f||g.resolveWith(b,c)}},i,j,k;if(d>1)for(i=new Array(d),j=new Array(d),k=new Array(d);d>b;b++)c[b]&&n.isFunction(c[b].promise)?c[b].promise().progress(h(b,j,i)).done(h(b,k,c)).fail(g.reject):--f;return f||g.resolveWith(k,c),g.promise()}});var I;n.fn.ready=function(a){return n.ready.promise().done(a),this},n.extend({isReady:!1,readyWait:1,holdReady:function(a){a?n.readyWait++:n.ready(!0)},ready:function(a){(a===!0?--n.readyWait:n.isReady)||(n.isReady=!0,a!==!0&&--n.readyWait>0||(I.resolveWith(d,[n]),n.fn.triggerHandler&&(n(d).triggerHandler("ready"),n(d).off("ready"))))}});function J(){d.addEventListener?(d.removeEventListener("DOMContentLoaded",K),a.removeEventListener("load",K)):(d.detachEvent("onreadystatechange",K),a.detachEvent("onload",K))}function K(){(d.addEventListener||"load"===a.event.type||"complete"===d.readyState)&&(J(),n.ready())}n.ready.promise=function(b){if(!I)if(I=n.Deferred(),"complete"===d.readyState||"loading"!==d.readyState&&!d.documentElement.doScroll)a.setTimeout(n.ready);else if(d.addEventListener)d.addEventListener("DOMContentLoaded",K),a.addEventListener("load",K);else{d.attachEvent("onreadystatechange",K),a.attachEvent("onload",K);var c=!1;try{c=null==a.frameElement&&d.documentElement}catch(e){}c&&c.doScroll&&!function f(){if(!n.isReady){try{c.doScroll("left")}catch(b){return a.setTimeout(f,50)}J(),n.ready()}}()}return I.promise(b)},n.ready.promise();var L;for(L in n(l))break;l.ownFirst="0"===L,l.inlineBlockNeedsLayout=!1,n(function(){var a,b,c,e;c=d.getElementsByTagName("body")[0],c&&c.style&&(b=d.createElement("div"),e=d.createElement("div"),e.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(e).appendChild(b),"undefined"!=typeof b.style.zoom&&(b.style.cssText="display:inline;margin:0;border:0;padding:1px;width:1px;zoom:1",l.inlineBlockNeedsLayout=a=3===b.offsetWidth,a&&(c.style.zoom=1)),c.removeChild(e))}),function(){var a=d.createElement("div");l.deleteExpando=!0;try{delete a.test}catch(b){l.deleteExpando=!1}a=null}();var M=function(a){var b=n.noData[(a.nodeName+" ").toLowerCase()],c=+a.nodeType||1;return 1!==c&&9!==c?!1:!b||b!==!0&&a.getAttribute("classid")===b},N=/^(?:\{[\w\W]*\}|\[[\w\W]*\])$/,O=/([A-Z])/g;function P(a,b,c){if(void 0===c&&1===a.nodeType){var d="data-"+b.replace(O,"-$1").toLowerCase();if(c=a.getAttribute(d),"string"==typeof c){try{c="true"===c?!0:"false"===c?!1:"null"===c?null:+c+""===c?+c:N.test(c)?n.parseJSON(c):c}catch(e){}n.data(a,b,c)}else c=void 0;
}return c}function Q(a){var b;for(b in a)if(("data"!==b||!n.isEmptyObject(a[b]))&&"toJSON"!==b)return!1;return!0}function R(a,b,d,e){if(M(a)){var f,g,h=n.expando,i=a.nodeType,j=i?n.cache:a,k=i?a[h]:a[h]&&h;if(k&&j[k]&&(e||j[k].data)||void 0!==d||"string"!=typeof b)return k||(k=i?a[h]=c.pop()||n.guid++:h),j[k]||(j[k]=i?{}:{toJSON:n.noop}),"object"!=typeof b&&"function"!=typeof b||(e?j[k]=n.extend(j[k],b):j[k].data=n.extend(j[k].data,b)),g=j[k],e||(g.data||(g.data={}),g=g.data),void 0!==d&&(g[n.camelCase(b)]=d),"string"==typeof b?(f=g[b],null==f&&(f=g[n.camelCase(b)])):f=g,f}}function S(a,b,c){if(M(a)){var d,e,f=a.nodeType,g=f?n.cache:a,h=f?a[n.expando]:n.expando;if(g[h]){if(b&&(d=c?g[h]:g[h].data)){n.isArray(b)?b=b.concat(n.map(b,n.camelCase)):b in d?b=[b]:(b=n.camelCase(b),b=b in d?[b]:b.split(" ")),e=b.length;while(e--)delete d[b[e]];if(c?!Q(d):!n.isEmptyObject(d))return}(c||(delete g[h].data,Q(g[h])))&&(f?n.cleanData([a],!0):l.deleteExpando||g!=g.window?delete g[h]:g[h]=void 0)}}}n.extend({cache:{},noData:{"applet ":!0,"embed ":!0,"object ":"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"},hasData:function(a){return a=a.nodeType?n.cache[a[n.expando]]:a[n.expando],!!a&&!Q(a)},data:function(a,b,c){return R(a,b,c)},removeData:function(a,b){return S(a,b)},_data:function(a,b,c){return R(a,b,c,!0)},_removeData:function(a,b){return S(a,b,!0)}}),n.fn.extend({data:function(a,b){var c,d,e,f=this[0],g=f&&f.attributes;if(void 0===a){if(this.length&&(e=n.data(f),1===f.nodeType&&!n._data(f,"parsedAttrs"))){c=g.length;while(c--)g[c]&&(d=g[c].name,0===d.indexOf("data-")&&(d=n.camelCase(d.slice(5)),P(f,d,e[d])));n._data(f,"parsedAttrs",!0)}return e}return"object"==typeof a?this.each(function(){n.data(this,a)}):arguments.length>1?this.each(function(){n.data(this,a,b)}):f?P(f,a,n.data(f,a)):void 0},removeData:function(a){return this.each(function(){n.removeData(this,a)})}}),n.extend({queue:function(a,b,c){var d;return a?(b=(b||"fx")+"queue",d=n._data(a,b),c&&(!d||n.isArray(c)?d=n._data(a,b,n.makeArray(c)):d.push(c)),d||[]):void 0},dequeue:function(a,b){b=b||"fx";var c=n.queue(a,b),d=c.length,e=c.shift(),f=n._queueHooks(a,b),g=function(){n.dequeue(a,b)};"inprogress"===e&&(e=c.shift(),d--),e&&("fx"===b&&c.unshift("inprogress"),delete f.stop,e.call(a,g,f)),!d&&f&&f.empty.fire()},_queueHooks:function(a,b){var c=b+"queueHooks";return n._data(a,c)||n._data(a,c,{empty:n.Callbacks("once memory").add(function(){n._removeData(a,b+"queue"),n._removeData(a,c)})})}}),n.fn.extend({queue:function(a,b){var c=2;return"string"!=typeof a&&(b=a,a="fx",c--),arguments.length<c?n.queue(this[0],a):void 0===b?this:this.each(function(){var c=n.queue(this,a,b);n._queueHooks(this,a),"fx"===a&&"inprogress"!==c[0]&&n.dequeue(this,a)})},dequeue:function(a){return this.each(function(){n.dequeue(this,a)})},clearQueue:function(a){return this.queue(a||"fx",[])},promise:function(a,b){var c,d=1,e=n.Deferred(),f=this,g=this.length,h=function(){--d||e.resolveWith(f,[f])};"string"!=typeof a&&(b=a,a=void 0),a=a||"fx";while(g--)c=n._data(f[g],a+"queueHooks"),c&&c.empty&&(d++,c.empty.add(h));return h(),e.promise(b)}}),function(){var a;l.shrinkWrapBlocks=function(){if(null!=a)return a;a=!1;var b,c,e;return c=d.getElementsByTagName("body")[0],c&&c.style?(b=d.createElement("div"),e=d.createElement("div"),e.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(e).appendChild(b),"undefined"!=typeof b.style.zoom&&(b.style.cssText="-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:1px;width:1px;zoom:1",b.appendChild(d.createElement("div")).style.width="5px",a=3!==b.offsetWidth),c.removeChild(e),a):void 0}}();var T=/[+-]?(?:\d*\.|)\d+(?:[eE][+-]?\d+|)/.source,U=new RegExp("^(?:([+-])=|)("+T+")([a-z%]*)$","i"),V=["Top","Right","Bottom","Left"],W=function(a,b){return a=b||a,"none"===n.css(a,"display")||!n.contains(a.ownerDocument,a)};function X(a,b,c,d){var e,f=1,g=20,h=d?function(){return d.cur()}:function(){return n.css(a,b,"")},i=h(),j=c&&c[3]||(n.cssNumber[b]?"":"px"),k=(n.cssNumber[b]||"px"!==j&&+i)&&U.exec(n.css(a,b));if(k&&k[3]!==j){j=j||k[3],c=c||[],k=+i||1;do f=f||".5",k/=f,n.style(a,b,k+j);while(f!==(f=h()/i)&&1!==f&&--g)}return c&&(k=+k||+i||0,e=c[1]?k+(c[1]+1)*c[2]:+c[2],d&&(d.unit=j,d.start=k,d.end=e)),e}var Y=function(a,b,c,d,e,f,g){var h=0,i=a.length,j=null==c;if("object"===n.type(c)){e=!0;for(h in c)Y(a,b,h,c[h],!0,f,g)}else if(void 0!==d&&(e=!0,n.isFunction(d)||(g=!0),j&&(g?(b.call(a,d),b=null):(j=b,b=function(a,b,c){return j.call(n(a),c)})),b))for(;i>h;h++)b(a[h],c,g?d:d.call(a[h],h,b(a[h],c)));return e?a:j?b.call(a):i?b(a[0],c):f},Z=/^(?:checkbox|radio)$/i,$=/<([\w:-]+)/,_=/^$|\/(?:java|ecma)script/i,aa=/^\s+/,ba="abbr|article|aside|audio|bdi|canvas|data|datalist|details|dialog|figcaption|figure|footer|header|hgroup|main|mark|meter|nav|output|picture|progress|section|summary|template|time|video";function ca(a){var b=ba.split("|"),c=a.createDocumentFragment();if(c.createElement)while(b.length)c.createElement(b.pop());return c}!function(){var a=d.createElement("div"),b=d.createDocumentFragment(),c=d.createElement("input");a.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",l.leadingWhitespace=3===a.firstChild.nodeType,l.tbody=!a.getElementsByTagName("tbody").length,l.htmlSerialize=!!a.getElementsByTagName("link").length,l.html5Clone="<:nav></:nav>"!==d.createElement("nav").cloneNode(!0).outerHTML,c.type="checkbox",c.checked=!0,b.appendChild(c),l.appendChecked=c.checked,a.innerHTML="<textarea>x</textarea>",l.noCloneChecked=!!a.cloneNode(!0).lastChild.defaultValue,b.appendChild(a),c=d.createElement("input"),c.setAttribute("type","radio"),c.setAttribute("checked","checked"),c.setAttribute("name","t"),a.appendChild(c),l.checkClone=a.cloneNode(!0).cloneNode(!0).lastChild.checked,l.noCloneEvent=!!a.addEventListener,a[n.expando]=1,l.attributes=!a.getAttribute(n.expando)}();var da={option:[1,"<select multiple='multiple'>","</select>"],legend:[1,"<fieldset>","</fieldset>"],area:[1,"<map>","</map>"],param:[1,"<object>","</object>"],thead:[1,"<table>","</table>"],tr:[2,"<table><tbody>","</tbody></table>"],col:[2,"<table><tbody></tbody><colgroup>","</colgroup></table>"],td:[3,"<table><tbody><tr>","</tr></tbody></table>"],_default:l.htmlSerialize?[0,"",""]:[1,"X<div>","</div>"]};da.optgroup=da.option,da.tbody=da.tfoot=da.colgroup=da.caption=da.thead,da.th=da.td;function ea(a,b){var c,d,e=0,f="undefined"!=typeof a.getElementsByTagName?a.getElementsByTagName(b||"*"):"undefined"!=typeof a.querySelectorAll?a.querySelectorAll(b||"*"):void 0;if(!f)for(f=[],c=a.childNodes||a;null!=(d=c[e]);e++)!b||n.nodeName(d,b)?f.push(d):n.merge(f,ea(d,b));return void 0===b||b&&n.nodeName(a,b)?n.merge([a],f):f}function fa(a,b){for(var c,d=0;null!=(c=a[d]);d++)n._data(c,"globalEval",!b||n._data(b[d],"globalEval"))}var ga=/<|&#?\w+;/,ha=/<tbody/i;function ia(a){Z.test(a.type)&&(a.defaultChecked=a.checked)}function ja(a,b,c,d,e){for(var f,g,h,i,j,k,m,o=a.length,p=ca(b),q=[],r=0;o>r;r++)if(g=a[r],g||0===g)if("object"===n.type(g))n.merge(q,g.nodeType?[g]:g);else if(ga.test(g)){i=i||p.appendChild(b.createElement("div")),j=($.exec(g)||["",""])[1].toLowerCase(),m=da[j]||da._default,i.innerHTML=m[1]+n.htmlPrefilter(g)+m[2],f=m[0];while(f--)i=i.lastChild;if(!l.leadingWhitespace&&aa.test(g)&&q.push(b.createTextNode(aa.exec(g)[0])),!l.tbody){g="table"!==j||ha.test(g)?"<table>"!==m[1]||ha.test(g)?0:i:i.firstChild,f=g&&g.childNodes.length;while(f--)n.nodeName(k=g.childNodes[f],"tbody")&&!k.childNodes.length&&g.removeChild(k)}n.merge(q,i.childNodes),i.textContent="";while(i.firstChild)i.removeChild(i.firstChild);i=p.lastChild}else q.push(b.createTextNode(g));i&&p.removeChild(i),l.appendChecked||n.grep(ea(q,"input"),ia),r=0;while(g=q[r++])if(d&&n.inArray(g,d)>-1)e&&e.push(g);else if(h=n.contains(g.ownerDocument,g),i=ea(p.appendChild(g),"script"),h&&fa(i),c){f=0;while(g=i[f++])_.test(g.type||"")&&c.push(g)}return i=null,p}!function(){var b,c,e=d.createElement("div");for(b in{submit:!0,change:!0,focusin:!0})c="on"+b,(l[b]=c in a)||(e.setAttribute(c,"t"),l[b]=e.attributes[c].expando===!1);e=null}();var ka=/^(?:input|select|textarea)$/i,la=/^key/,ma=/^(?:mouse|pointer|contextmenu|drag|drop)|click/,na=/^(?:focusinfocus|focusoutblur)$/,oa=/^([^.]*)(?:\.(.+)|)/;function pa(){return!0}function qa(){return!1}function ra(){try{return d.activeElement}catch(a){}}function sa(a,b,c,d,e,f){var g,h;if("object"==typeof b){"string"!=typeof c&&(d=d||c,c=void 0);for(h in b)sa(a,h,c,d,b[h],f);return a}if(null==d&&null==e?(e=c,d=c=void 0):null==e&&("string"==typeof c?(e=d,d=void 0):(e=d,d=c,c=void 0)),e===!1)e=qa;else if(!e)return a;return 1===f&&(g=e,e=function(a){return n().off(a),g.apply(this,arguments)},e.guid=g.guid||(g.guid=n.guid++)),a.each(function(){n.event.add(this,b,e,d,c)})}n.event={global:{},add:function(a,b,c,d,e){var f,g,h,i,j,k,l,m,o,p,q,r=n._data(a);if(r){c.handler&&(i=c,c=i.handler,e=i.selector),c.guid||(c.guid=n.guid++),(g=r.events)||(g=r.events={}),(k=r.handle)||(k=r.handle=function(a){return"undefined"==typeof n||a&&n.event.triggered===a.type?void 0:n.event.dispatch.apply(k.elem,arguments)},k.elem=a),b=(b||"").match(G)||[""],h=b.length;while(h--)f=oa.exec(b[h])||[],o=q=f[1],p=(f[2]||"").split(".").sort(),o&&(j=n.event.special[o]||{},o=(e?j.delegateType:j.bindType)||o,j=n.event.special[o]||{},l=n.extend({type:o,origType:q,data:d,handler:c,guid:c.guid,selector:e,needsContext:e&&n.expr.match.needsContext.test(e),namespace:p.join(".")},i),(m=g[o])||(m=g[o]=[],m.delegateCount=0,j.setup&&j.setup.call(a,d,p,k)!==!1||(a.addEventListener?a.addEventListener(o,k,!1):a.attachEvent&&a.attachEvent("on"+o,k))),j.add&&(j.add.call(a,l),l.handler.guid||(l.handler.guid=c.guid)),e?m.splice(m.delegateCount++,0,l):m.push(l),n.event.global[o]=!0);a=null}},remove:function(a,b,c,d,e){var f,g,h,i,j,k,l,m,o,p,q,r=n.hasData(a)&&n._data(a);if(r&&(k=r.events)){b=(b||"").match(G)||[""],j=b.length;while(j--)if(h=oa.exec(b[j])||[],o=q=h[1],p=(h[2]||"").split(".").sort(),o){l=n.event.special[o]||{},o=(d?l.delegateType:l.bindType)||o,m=k[o]||[],h=h[2]&&new RegExp("(^|\\.)"+p.join("\\.(?:.*\\.|)")+"(\\.|$)"),i=f=m.length;while(f--)g=m[f],!e&&q!==g.origType||c&&c.guid!==g.guid||h&&!h.test(g.namespace)||d&&d!==g.selector&&("**"!==d||!g.selector)||(m.splice(f,1),g.selector&&m.delegateCount--,l.remove&&l.remove.call(a,g));i&&!m.length&&(l.teardown&&l.teardown.call(a,p,r.handle)!==!1||n.removeEvent(a,o,r.handle),delete k[o])}else for(o in k)n.event.remove(a,o+b[j],c,d,!0);n.isEmptyObject(k)&&(delete r.handle,n._removeData(a,"events"))}},trigger:function(b,c,e,f){var g,h,i,j,l,m,o,p=[e||d],q=k.call(b,"type")?b.type:b,r=k.call(b,"namespace")?b.namespace.split("."):[];if(i=m=e=e||d,3!==e.nodeType&&8!==e.nodeType&&!na.test(q+n.event.triggered)&&(q.indexOf(".")>-1&&(r=q.split("."),q=r.shift(),r.sort()),h=q.indexOf(":")<0&&"on"+q,b=b[n.expando]?b:new n.Event(q,"object"==typeof b&&b),b.isTrigger=f?2:3,b.namespace=r.join("."),b.rnamespace=b.namespace?new RegExp("(^|\\.)"+r.join("\\.(?:.*\\.|)")+"(\\.|$)"):null,b.result=void 0,b.target||(b.target=e),c=null==c?[b]:n.makeArray(c,[b]),l=n.event.special[q]||{},f||!l.trigger||l.trigger.apply(e,c)!==!1)){if(!f&&!l.noBubble&&!n.isWindow(e)){for(j=l.delegateType||q,na.test(j+q)||(i=i.parentNode);i;i=i.parentNode)p.push(i),m=i;m===(e.ownerDocument||d)&&p.push(m.defaultView||m.parentWindow||a)}o=0;while((i=p[o++])&&!b.isPropagationStopped())b.type=o>1?j:l.bindType||q,g=(n._data(i,"events")||{})[b.type]&&n._data(i,"handle"),g&&g.apply(i,c),g=h&&i[h],g&&g.apply&&M(i)&&(b.result=g.apply(i,c),b.result===!1&&b.preventDefault());if(b.type=q,!f&&!b.isDefaultPrevented()&&(!l._default||l._default.apply(p.pop(),c)===!1)&&M(e)&&h&&e[q]&&!n.isWindow(e)){m=e[h],m&&(e[h]=null),n.event.triggered=q;try{e[q]()}catch(s){}n.event.triggered=void 0,m&&(e[h]=m)}return b.result}},dispatch:function(a){a=n.event.fix(a);var b,c,d,f,g,h=[],i=e.call(arguments),j=(n._data(this,"events")||{})[a.type]||[],k=n.event.special[a.type]||{};if(i[0]=a,a.delegateTarget=this,!k.preDispatch||k.preDispatch.call(this,a)!==!1){h=n.event.handlers.call(this,a,j),b=0;while((f=h[b++])&&!a.isPropagationStopped()){a.currentTarget=f.elem,c=0;while((g=f.handlers[c++])&&!a.isImmediatePropagationStopped())a.rnamespace&&!a.rnamespace.test(g.namespace)||(a.handleObj=g,a.data=g.data,d=((n.event.special[g.origType]||{}).handle||g.handler).apply(f.elem,i),void 0!==d&&(a.result=d)===!1&&(a.preventDefault(),a.stopPropagation()))}return k.postDispatch&&k.postDispatch.call(this,a),a.result}},handlers:function(a,b){var c,d,e,f,g=[],h=b.delegateCount,i=a.target;if(h&&i.nodeType&&("click"!==a.type||isNaN(a.button)||a.button<1))for(;i!=this;i=i.parentNode||this)if(1===i.nodeType&&(i.disabled!==!0||"click"!==a.type)){for(d=[],c=0;h>c;c++)f=b[c],e=f.selector+" ",void 0===d[e]&&(d[e]=f.needsContext?n(e,this).index(i)>-1:n.find(e,this,null,[i]).length),d[e]&&d.push(f);d.length&&g.push({elem:i,handlers:d})}return h<b.length&&g.push({elem:this,handlers:b.slice(h)}),g},fix:function(a){if(a[n.expando])return a;var b,c,e,f=a.type,g=a,h=this.fixHooks[f];h||(this.fixHooks[f]=h=ma.test(f)?this.mouseHooks:la.test(f)?this.keyHooks:{}),e=h.props?this.props.concat(h.props):this.props,a=new n.Event(g),b=e.length;while(b--)c=e[b],a[c]=g[c];return a.target||(a.target=g.srcElement||d),3===a.target.nodeType&&(a.target=a.target.parentNode),a.metaKey=!!a.metaKey,h.filter?h.filter(a,g):a},props:"altKey bubbles cancelable ctrlKey currentTarget detail eventPhase metaKey relatedTarget shiftKey target timeStamp view which".split(" "),fixHooks:{},keyHooks:{props:"char charCode key keyCode".split(" "),filter:function(a,b){return null==a.which&&(a.which=null!=b.charCode?b.charCode:b.keyCode),a}},mouseHooks:{props:"button buttons clientX clientY fromElement offsetX offsetY pageX pageY screenX screenY toElement".split(" "),filter:function(a,b){var c,e,f,g=b.button,h=b.fromElement;return null==a.pageX&&null!=b.clientX&&(e=a.target.ownerDocument||d,f=e.documentElement,c=e.body,a.pageX=b.clientX+(f&&f.scrollLeft||c&&c.scrollLeft||0)-(f&&f.clientLeft||c&&c.clientLeft||0),a.pageY=b.clientY+(f&&f.scrollTop||c&&c.scrollTop||0)-(f&&f.clientTop||c&&c.clientTop||0)),!a.relatedTarget&&h&&(a.relatedTarget=h===a.target?b.toElement:h),a.which||void 0===g||(a.which=1&g?1:2&g?3:4&g?2:0),a}},special:{load:{noBubble:!0},focus:{trigger:function(){if(this!==ra()&&this.focus)try{return this.focus(),!1}catch(a){}},delegateType:"focusin"},blur:{trigger:function(){return this===ra()&&this.blur?(this.blur(),!1):void 0},delegateType:"focusout"},click:{trigger:function(){return n.nodeName(this,"input")&&"checkbox"===this.type&&this.click?(this.click(),!1):void 0},_default:function(a){return n.nodeName(a.target,"a")}},beforeunload:{postDispatch:function(a){void 0!==a.result&&a.originalEvent&&(a.originalEvent.returnValue=a.result)}}},simulate:function(a,b,c){var d=n.extend(new n.Event,c,{type:a,isSimulated:!0});n.event.trigger(d,null,b),d.isDefaultPrevented()&&c.preventDefault()}},n.removeEvent=d.removeEventListener?function(a,b,c){a.removeEventListener&&a.removeEventListener(b,c)}:function(a,b,c){var d="on"+b;a.detachEvent&&("undefined"==typeof a[d]&&(a[d]=null),a.detachEvent(d,c))},n.Event=function(a,b){return this instanceof n.Event?(a&&a.type?(this.originalEvent=a,this.type=a.type,this.isDefaultPrevented=a.defaultPrevented||void 0===a.defaultPrevented&&a.returnValue===!1?pa:qa):this.type=a,b&&n.extend(this,b),this.timeStamp=a&&a.timeStamp||n.now(),void(this[n.expando]=!0)):new n.Event(a,b)},n.Event.prototype={constructor:n.Event,isDefaultPrevented:qa,isPropagationStopped:qa,isImmediatePropagationStopped:qa,preventDefault:function(){var a=this.originalEvent;this.isDefaultPrevented=pa,a&&(a.preventDefault?a.preventDefault():a.returnValue=!1)},stopPropagation:function(){var a=this.originalEvent;this.isPropagationStopped=pa,a&&!this.isSimulated&&(a.stopPropagation&&a.stopPropagation(),a.cancelBubble=!0)},stopImmediatePropagation:function(){var a=this.originalEvent;this.isImmediatePropagationStopped=pa,a&&a.stopImmediatePropagation&&a.stopImmediatePropagation(),this.stopPropagation()}},n.each({mouseenter:"mouseover",mouseleave:"mouseout",pointerenter:"pointerover",pointerleave:"pointerout"},function(a,b){n.event.special[a]={delegateType:b,bindType:b,handle:function(a){var c,d=this,e=a.relatedTarget,f=a.handleObj;return e&&(e===d||n.contains(d,e))||(a.type=f.origType,c=f.handler.apply(this,arguments),a.type=b),c}}}),l.submit||(n.event.special.submit={setup:function(){return n.nodeName(this,"form")?!1:void n.event.add(this,"click._submit keypress._submit",function(a){var b=a.target,c=n.nodeName(b,"input")||n.nodeName(b,"button")?n.prop(b,"form"):void 0;c&&!n._data(c,"submit")&&(n.event.add(c,"submit._submit",function(a){a._submitBubble=!0}),n._data(c,"submit",!0))})},postDispatch:function(a){a._submitBubble&&(delete a._submitBubble,this.parentNode&&!a.isTrigger&&n.event.simulate("submit",this.parentNode,a))},teardown:function(){return n.nodeName(this,"form")?!1:void n.event.remove(this,"._submit")}}),l.change||(n.event.special.change={setup:function(){return ka.test(this.nodeName)?("checkbox"!==this.type&&"radio"!==this.type||(n.event.add(this,"propertychange._change",function(a){"checked"===a.originalEvent.propertyName&&(this._justChanged=!0)}),n.event.add(this,"click._change",function(a){this._justChanged&&!a.isTrigger&&(this._justChanged=!1),n.event.simulate("change",this,a)})),!1):void n.event.add(this,"beforeactivate._change",function(a){var b=a.target;ka.test(b.nodeName)&&!n._data(b,"change")&&(n.event.add(b,"change._change",function(a){!this.parentNode||a.isSimulated||a.isTrigger||n.event.simulate("change",this.parentNode,a)}),n._data(b,"change",!0))})},handle:function(a){var b=a.target;return this!==b||a.isSimulated||a.isTrigger||"radio"!==b.type&&"checkbox"!==b.type?a.handleObj.handler.apply(this,arguments):void 0},teardown:function(){return n.event.remove(this,"._change"),!ka.test(this.nodeName)}}),l.focusin||n.each({focus:"focusin",blur:"focusout"},function(a,b){var c=function(a){n.event.simulate(b,a.target,n.event.fix(a))};n.event.special[b]={setup:function(){var d=this.ownerDocument||this,e=n._data(d,b);e||d.addEventListener(a,c,!0),n._data(d,b,(e||0)+1)},teardown:function(){var d=this.ownerDocument||this,e=n._data(d,b)-1;e?n._data(d,b,e):(d.removeEventListener(a,c,!0),n._removeData(d,b))}}}),n.fn.extend({on:function(a,b,c,d){return sa(this,a,b,c,d)},one:function(a,b,c,d){return sa(this,a,b,c,d,1)},off:function(a,b,c){var d,e;if(a&&a.preventDefault&&a.handleObj)return d=a.handleObj,n(a.delegateTarget).off(d.namespace?d.origType+"."+d.namespace:d.origType,d.selector,d.handler),this;if("object"==typeof a){for(e in a)this.off(e,b,a[e]);return this}return b!==!1&&"function"!=typeof b||(c=b,b=void 0),c===!1&&(c=qa),this.each(function(){n.event.remove(this,a,c,b)})},trigger:function(a,b){return this.each(function(){n.event.trigger(a,b,this)})},triggerHandler:function(a,b){var c=this[0];return c?n.event.trigger(a,b,c,!0):void 0}});var ta=/ jQuery\d+="(?:null|\d+)"/g,ua=new RegExp("<(?:"+ba+")[\\s/>]","i"),va=/<(?!area|br|col|embed|hr|img|input|link|meta|param)(([\w:-]+)[^>]*)\/>/gi,wa=/<script|<style|<link/i,xa=/checked\s*(?:[^=]|=\s*.checked.)/i,ya=/^true\/(.*)/,za=/^\s*<!(?:\[CDATA\[|--)|(?:\]\]|--)>\s*$/g,Aa=ca(d),Ba=Aa.appendChild(d.createElement("div"));function Ca(a,b){return n.nodeName(a,"table")&&n.nodeName(11!==b.nodeType?b:b.firstChild,"tr")?a.getElementsByTagName("tbody")[0]||a.appendChild(a.ownerDocument.createElement("tbody")):a}function Da(a){return a.type=(null!==n.find.attr(a,"type"))+"/"+a.type,a}function Ea(a){var b=ya.exec(a.type);return b?a.type=b[1]:a.removeAttribute("type"),a}function Fa(a,b){if(1===b.nodeType&&n.hasData(a)){var c,d,e,f=n._data(a),g=n._data(b,f),h=f.events;if(h){delete g.handle,g.events={};for(c in h)for(d=0,e=h[c].length;e>d;d++)n.event.add(b,c,h[c][d])}g.data&&(g.data=n.extend({},g.data))}}function Ga(a,b){var c,d,e;if(1===b.nodeType){if(c=b.nodeName.toLowerCase(),!l.noCloneEvent&&b[n.expando]){e=n._data(b);for(d in e.events)n.removeEvent(b,d,e.handle);b.removeAttribute(n.expando)}"script"===c&&b.text!==a.text?(Da(b).text=a.text,Ea(b)):"object"===c?(b.parentNode&&(b.outerHTML=a.outerHTML),l.html5Clone&&a.innerHTML&&!n.trim(b.innerHTML)&&(b.innerHTML=a.innerHTML)):"input"===c&&Z.test(a.type)?(b.defaultChecked=b.checked=a.checked,b.value!==a.value&&(b.value=a.value)):"option"===c?b.defaultSelected=b.selected=a.defaultSelected:"input"!==c&&"textarea"!==c||(b.defaultValue=a.defaultValue)}}function Ha(a,b,c,d){b=f.apply([],b);var e,g,h,i,j,k,m=0,o=a.length,p=o-1,q=b[0],r=n.isFunction(q);if(r||o>1&&"string"==typeof q&&!l.checkClone&&xa.test(q))return a.each(function(e){var f=a.eq(e);r&&(b[0]=q.call(this,e,f.html())),Ha(f,b,c,d)});if(o&&(k=ja(b,a[0].ownerDocument,!1,a,d),e=k.firstChild,1===k.childNodes.length&&(k=e),e||d)){for(i=n.map(ea(k,"script"),Da),h=i.length;o>m;m++)g=k,m!==p&&(g=n.clone(g,!0,!0),h&&n.merge(i,ea(g,"script"))),c.call(a[m],g,m);if(h)for(j=i[i.length-1].ownerDocument,n.map(i,Ea),m=0;h>m;m++)g=i[m],_.test(g.type||"")&&!n._data(g,"globalEval")&&n.contains(j,g)&&(g.src?n._evalUrl&&n._evalUrl(g.src):n.globalEval((g.text||g.textContent||g.innerHTML||"").replace(za,"")));k=e=null}return a}function Ia(a,b,c){for(var d,e=b?n.filter(b,a):a,f=0;null!=(d=e[f]);f++)c||1!==d.nodeType||n.cleanData(ea(d)),d.parentNode&&(c&&n.contains(d.ownerDocument,d)&&fa(ea(d,"script")),d.parentNode.removeChild(d));return a}n.extend({htmlPrefilter:function(a){return a.replace(va,"<$1></$2>")},clone:function(a,b,c){var d,e,f,g,h,i=n.contains(a.ownerDocument,a);if(l.html5Clone||n.isXMLDoc(a)||!ua.test("<"+a.nodeName+">")?f=a.cloneNode(!0):(Ba.innerHTML=a.outerHTML,Ba.removeChild(f=Ba.firstChild)),!(l.noCloneEvent&&l.noCloneChecked||1!==a.nodeType&&11!==a.nodeType||n.isXMLDoc(a)))for(d=ea(f),h=ea(a),g=0;null!=(e=h[g]);++g)d[g]&&Ga(e,d[g]);if(b)if(c)for(h=h||ea(a),d=d||ea(f),g=0;null!=(e=h[g]);g++)Fa(e,d[g]);else Fa(a,f);return d=ea(f,"script"),d.length>0&&fa(d,!i&&ea(a,"script")),d=h=e=null,f},cleanData:function(a,b){for(var d,e,f,g,h=0,i=n.expando,j=n.cache,k=l.attributes,m=n.event.special;null!=(d=a[h]);h++)if((b||M(d))&&(f=d[i],g=f&&j[f])){if(g.events)for(e in g.events)m[e]?n.event.remove(d,e):n.removeEvent(d,e,g.handle);j[f]&&(delete j[f],k||"undefined"==typeof d.removeAttribute?d[i]=void 0:d.removeAttribute(i),c.push(f))}}}),n.fn.extend({domManip:Ha,detach:function(a){return Ia(this,a,!0)},remove:function(a){return Ia(this,a)},text:function(a){return Y(this,function(a){return void 0===a?n.text(this):this.empty().append((this[0]&&this[0].ownerDocument||d).createTextNode(a))},null,a,arguments.length)},append:function(){return Ha(this,arguments,function(a){if(1===this.nodeType||11===this.nodeType||9===this.nodeType){var b=Ca(this,a);b.appendChild(a)}})},prepend:function(){return Ha(this,arguments,function(a){if(1===this.nodeType||11===this.nodeType||9===this.nodeType){var b=Ca(this,a);b.insertBefore(a,b.firstChild)}})},before:function(){return Ha(this,arguments,function(a){this.parentNode&&this.parentNode.insertBefore(a,this)})},after:function(){return Ha(this,arguments,function(a){this.parentNode&&this.parentNode.insertBefore(a,this.nextSibling)})},empty:function(){for(var a,b=0;null!=(a=this[b]);b++){1===a.nodeType&&n.cleanData(ea(a,!1));while(a.firstChild)a.removeChild(a.firstChild);a.options&&n.nodeName(a,"select")&&(a.options.length=0)}return this},clone:function(a,b){return a=null==a?!1:a,b=null==b?a:b,this.map(function(){return n.clone(this,a,b)})},html:function(a){return Y(this,function(a){var b=this[0]||{},c=0,d=this.length;if(void 0===a)return 1===b.nodeType?b.innerHTML.replace(ta,""):void 0;if("string"==typeof a&&!wa.test(a)&&(l.htmlSerialize||!ua.test(a))&&(l.leadingWhitespace||!aa.test(a))&&!da[($.exec(a)||["",""])[1].toLowerCase()]){a=n.htmlPrefilter(a);try{for(;d>c;c++)b=this[c]||{},1===b.nodeType&&(n.cleanData(ea(b,!1)),b.innerHTML=a);b=0}catch(e){}}b&&this.empty().append(a)},null,a,arguments.length)},replaceWith:function(){var a=[];return Ha(this,arguments,function(b){var c=this.parentNode;n.inArray(this,a)<0&&(n.cleanData(ea(this)),c&&c.replaceChild(b,this))},a)}}),n.each({appendTo:"append",prependTo:"prepend",insertBefore:"before",insertAfter:"after",replaceAll:"replaceWith"},function(a,b){n.fn[a]=function(a){for(var c,d=0,e=[],f=n(a),h=f.length-1;h>=d;d++)c=d===h?this:this.clone(!0),n(f[d])[b](c),g.apply(e,c.get());return this.pushStack(e)}});var Ja,Ka={HTML:"block",BODY:"block"};function La(a,b){var c=n(b.createElement(a)).appendTo(b.body),d=n.css(c[0],"display");return c.detach(),d}function Ma(a){var b=d,c=Ka[a];return c||(c=La(a,b),"none"!==c&&c||(Ja=(Ja||n("<iframe frameborder='0' width='0' height='0'/>")).appendTo(b.documentElement),b=(Ja[0].contentWindow||Ja[0].contentDocument).document,b.write(),b.close(),c=La(a,b),Ja.detach()),Ka[a]=c),c}var Na=/^margin/,Oa=new RegExp("^("+T+")(?!px)[a-z%]+$","i"),Pa=function(a,b,c,d){var e,f,g={};for(f in b)g[f]=a.style[f],a.style[f]=b[f];e=c.apply(a,d||[]);for(f in b)a.style[f]=g[f];return e},Qa=d.documentElement;!function(){var b,c,e,f,g,h,i=d.createElement("div"),j=d.createElement("div");if(j.style){j.style.cssText="float:left;opacity:.5",l.opacity="0.5"===j.style.opacity,l.cssFloat=!!j.style.cssFloat,j.style.backgroundClip="content-box",j.cloneNode(!0).style.backgroundClip="",l.clearCloneStyle="content-box"===j.style.backgroundClip,i=d.createElement("div"),i.style.cssText="border:0;width:8px;height:0;top:0;left:-9999px;padding:0;margin-top:1px;position:absolute",j.innerHTML="",i.appendChild(j),l.boxSizing=""===j.style.boxSizing||""===j.style.MozBoxSizing||""===j.style.WebkitBoxSizing,n.extend(l,{reliableHiddenOffsets:function(){return null==b&&k(),f},boxSizingReliable:function(){return null==b&&k(),e},pixelMarginRight:function(){return null==b&&k(),c},pixelPosition:function(){return null==b&&k(),b},reliableMarginRight:function(){return null==b&&k(),g},reliableMarginLeft:function(){return null==b&&k(),h}});function k(){var k,l,m=d.documentElement;m.appendChild(i),j.style.cssText="-webkit-box-sizing:border-box;box-sizing:border-box;position:relative;display:block;margin:auto;border:1px;padding:1px;top:1%;width:50%",b=e=h=!1,c=g=!0,a.getComputedStyle&&(l=a.getComputedStyle(j),b="1%"!==(l||{}).top,h="2px"===(l||{}).marginLeft,e="4px"===(l||{width:"4px"}).width,j.style.marginRight="50%",c="4px"===(l||{marginRight:"4px"}).marginRight,k=j.appendChild(d.createElement("div")),k.style.cssText=j.style.cssText="-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:0",k.style.marginRight=k.style.width="0",j.style.width="1px",g=!parseFloat((a.getComputedStyle(k)||{}).marginRight),j.removeChild(k)),j.style.display="none",f=0===j.getClientRects().length,f&&(j.style.display="",j.innerHTML="<table><tr><td></td><td>t</td></tr></table>",j.childNodes[0].style.borderCollapse="separate",k=j.getElementsByTagName("td"),k[0].style.cssText="margin:0;border:0;padding:0;display:none",f=0===k[0].offsetHeight,f&&(k[0].style.display="",k[1].style.display="none",f=0===k[0].offsetHeight)),m.removeChild(i)}}}();var Ra,Sa,Ta=/^(top|right|bottom|left)$/;a.getComputedStyle?(Ra=function(b){var c=b.ownerDocument.defaultView;return c&&c.opener||(c=a),c.getComputedStyle(b)},Sa=function(a,b,c){var d,e,f,g,h=a.style;return c=c||Ra(a),g=c?c.getPropertyValue(b)||c[b]:void 0,""!==g&&void 0!==g||n.contains(a.ownerDocument,a)||(g=n.style(a,b)),c&&!l.pixelMarginRight()&&Oa.test(g)&&Na.test(b)&&(d=h.width,e=h.minWidth,f=h.maxWidth,h.minWidth=h.maxWidth=h.width=g,g=c.width,h.width=d,h.minWidth=e,h.maxWidth=f),void 0===g?g:g+""}):Qa.currentStyle&&(Ra=function(a){return a.currentStyle},Sa=function(a,b,c){var d,e,f,g,h=a.style;return c=c||Ra(a),g=c?c[b]:void 0,null==g&&h&&h[b]&&(g=h[b]),Oa.test(g)&&!Ta.test(b)&&(d=h.left,e=a.runtimeStyle,f=e&&e.left,f&&(e.left=a.currentStyle.left),h.left="fontSize"===b?"1em":g,g=h.pixelLeft+"px",h.left=d,f&&(e.left=f)),void 0===g?g:g+""||"auto"});function Ua(a,b){return{get:function(){return a()?void delete this.get:(this.get=b).apply(this,arguments)}}}var Va=/alpha\([^)]*\)/i,Wa=/opacity\s*=\s*([^)]*)/i,Xa=/^(none|table(?!-c[ea]).+)/,Ya=new RegExp("^("+T+")(.*)$","i"),Za={position:"absolute",visibility:"hidden",display:"block"},$a={letterSpacing:"0",fontWeight:"400"},_a=["Webkit","O","Moz","ms"],ab=d.createElement("div").style;function bb(a){if(a in ab)return a;var b=a.charAt(0).toUpperCase()+a.slice(1),c=_a.length;while(c--)if(a=_a[c]+b,a in ab)return a}function cb(a,b){for(var c,d,e,f=[],g=0,h=a.length;h>g;g++)d=a[g],d.style&&(f[g]=n._data(d,"olddisplay"),c=d.style.display,b?(f[g]||"none"!==c||(d.style.display=""),""===d.style.display&&W(d)&&(f[g]=n._data(d,"olddisplay",Ma(d.nodeName)))):(e=W(d),(c&&"none"!==c||!e)&&n._data(d,"olddisplay",e?c:n.css(d,"display"))));for(g=0;h>g;g++)d=a[g],d.style&&(b&&"none"!==d.style.display&&""!==d.style.display||(d.style.display=b?f[g]||"":"none"));return a}function db(a,b,c){var d=Ya.exec(b);return d?Math.max(0,d[1]-(c||0))+(d[2]||"px"):b}function eb(a,b,c,d,e){for(var f=c===(d?"border":"content")?4:"width"===b?1:0,g=0;4>f;f+=2)"margin"===c&&(g+=n.css(a,c+V[f],!0,e)),d?("content"===c&&(g-=n.css(a,"padding"+V[f],!0,e)),"margin"!==c&&(g-=n.css(a,"border"+V[f]+"Width",!0,e))):(g+=n.css(a,"padding"+V[f],!0,e),"padding"!==c&&(g+=n.css(a,"border"+V[f]+"Width",!0,e)));return g}function fb(a,b,c){var d=!0,e="width"===b?a.offsetWidth:a.offsetHeight,f=Ra(a),g=l.boxSizing&&"border-box"===n.css(a,"boxSizing",!1,f);if(0>=e||null==e){if(e=Sa(a,b,f),(0>e||null==e)&&(e=a.style[b]),Oa.test(e))return e;d=g&&(l.boxSizingReliable()||e===a.style[b]),e=parseFloat(e)||0}return e+eb(a,b,c||(g?"border":"content"),d,f)+"px"}n.extend({cssHooks:{opacity:{get:function(a,b){if(b){var c=Sa(a,"opacity");return""===c?"1":c}}}},cssNumber:{animationIterationCount:!0,columnCount:!0,fillOpacity:!0,flexGrow:!0,flexShrink:!0,fontWeight:!0,lineHeight:!0,opacity:!0,order:!0,orphans:!0,widows:!0,zIndex:!0,zoom:!0},cssProps:{"float":l.cssFloat?"cssFloat":"styleFloat"},style:function(a,b,c,d){if(a&&3!==a.nodeType&&8!==a.nodeType&&a.style){var e,f,g,h=n.camelCase(b),i=a.style;if(b=n.cssProps[h]||(n.cssProps[h]=bb(h)||h),g=n.cssHooks[b]||n.cssHooks[h],void 0===c)return g&&"get"in g&&void 0!==(e=g.get(a,!1,d))?e:i[b];if(f=typeof c,"string"===f&&(e=U.exec(c))&&e[1]&&(c=X(a,b,e),f="number"),null!=c&&c===c&&("number"===f&&(c+=e&&e[3]||(n.cssNumber[h]?"":"px")),l.clearCloneStyle||""!==c||0!==b.indexOf("background")||(i[b]="inherit"),!(g&&"set"in g&&void 0===(c=g.set(a,c,d)))))try{i[b]=c}catch(j){}}},css:function(a,b,c,d){var e,f,g,h=n.camelCase(b);return b=n.cssProps[h]||(n.cssProps[h]=bb(h)||h),g=n.cssHooks[b]||n.cssHooks[h],g&&"get"in g&&(f=g.get(a,!0,c)),void 0===f&&(f=Sa(a,b,d)),"normal"===f&&b in $a&&(f=$a[b]),""===c||c?(e=parseFloat(f),c===!0||isFinite(e)?e||0:f):f}}),n.each(["height","width"],function(a,b){n.cssHooks[b]={get:function(a,c,d){return c?Xa.test(n.css(a,"display"))&&0===a.offsetWidth?Pa(a,Za,function(){return fb(a,b,d)}):fb(a,b,d):void 0},set:function(a,c,d){var e=d&&Ra(a);return db(a,c,d?eb(a,b,d,l.boxSizing&&"border-box"===n.css(a,"boxSizing",!1,e),e):0)}}}),l.opacity||(n.cssHooks.opacity={get:function(a,b){return Wa.test((b&&a.currentStyle?a.currentStyle.filter:a.style.filter)||"")?.01*parseFloat(RegExp.$1)+"":b?"1":""},set:function(a,b){var c=a.style,d=a.currentStyle,e=n.isNumeric(b)?"alpha(opacity="+100*b+")":"",f=d&&d.filter||c.filter||"";c.zoom=1,(b>=1||""===b)&&""===n.trim(f.replace(Va,""))&&c.removeAttribute&&(c.removeAttribute("filter"),""===b||d&&!d.filter)||(c.filter=Va.test(f)?f.replace(Va,e):f+" "+e)}}),n.cssHooks.marginRight=Ua(l.reliableMarginRight,function(a,b){return b?Pa(a,{display:"inline-block"},Sa,[a,"marginRight"]):void 0}),n.cssHooks.marginLeft=Ua(l.reliableMarginLeft,function(a,b){return b?(parseFloat(Sa(a,"marginLeft"))||(n.contains(a.ownerDocument,a)?a.getBoundingClientRect().left-Pa(a,{
marginLeft:0},function(){return a.getBoundingClientRect().left}):0))+"px":void 0}),n.each({margin:"",padding:"",border:"Width"},function(a,b){n.cssHooks[a+b]={expand:function(c){for(var d=0,e={},f="string"==typeof c?c.split(" "):[c];4>d;d++)e[a+V[d]+b]=f[d]||f[d-2]||f[0];return e}},Na.test(a)||(n.cssHooks[a+b].set=db)}),n.fn.extend({css:function(a,b){return Y(this,function(a,b,c){var d,e,f={},g=0;if(n.isArray(b)){for(d=Ra(a),e=b.length;e>g;g++)f[b[g]]=n.css(a,b[g],!1,d);return f}return void 0!==c?n.style(a,b,c):n.css(a,b)},a,b,arguments.length>1)},show:function(){return cb(this,!0)},hide:function(){return cb(this)},toggle:function(a){return"boolean"==typeof a?a?this.show():this.hide():this.each(function(){W(this)?n(this).show():n(this).hide()})}});function gb(a,b,c,d,e){return new gb.prototype.init(a,b,c,d,e)}n.Tween=gb,gb.prototype={constructor:gb,init:function(a,b,c,d,e,f){this.elem=a,this.prop=c,this.easing=e||n.easing._default,this.options=b,this.start=this.now=this.cur(),this.end=d,this.unit=f||(n.cssNumber[c]?"":"px")},cur:function(){var a=gb.propHooks[this.prop];return a&&a.get?a.get(this):gb.propHooks._default.get(this)},run:function(a){var b,c=gb.propHooks[this.prop];return this.options.duration?this.pos=b=n.easing[this.easing](a,this.options.duration*a,0,1,this.options.duration):this.pos=b=a,this.now=(this.end-this.start)*b+this.start,this.options.step&&this.options.step.call(this.elem,this.now,this),c&&c.set?c.set(this):gb.propHooks._default.set(this),this}},gb.prototype.init.prototype=gb.prototype,gb.propHooks={_default:{get:function(a){var b;return 1!==a.elem.nodeType||null!=a.elem[a.prop]&&null==a.elem.style[a.prop]?a.elem[a.prop]:(b=n.css(a.elem,a.prop,""),b&&"auto"!==b?b:0)},set:function(a){n.fx.step[a.prop]?n.fx.step[a.prop](a):1!==a.elem.nodeType||null==a.elem.style[n.cssProps[a.prop]]&&!n.cssHooks[a.prop]?a.elem[a.prop]=a.now:n.style(a.elem,a.prop,a.now+a.unit)}}},gb.propHooks.scrollTop=gb.propHooks.scrollLeft={set:function(a){a.elem.nodeType&&a.elem.parentNode&&(a.elem[a.prop]=a.now)}},n.easing={linear:function(a){return a},swing:function(a){return.5-Math.cos(a*Math.PI)/2},_default:"swing"},n.fx=gb.prototype.init,n.fx.step={};var hb,ib,jb=/^(?:toggle|show|hide)$/,kb=/queueHooks$/;function lb(){return a.setTimeout(function(){hb=void 0}),hb=n.now()}function mb(a,b){var c,d={height:a},e=0;for(b=b?1:0;4>e;e+=2-b)c=V[e],d["margin"+c]=d["padding"+c]=a;return b&&(d.opacity=d.width=a),d}function nb(a,b,c){for(var d,e=(qb.tweeners[b]||[]).concat(qb.tweeners["*"]),f=0,g=e.length;g>f;f++)if(d=e[f].call(c,b,a))return d}function ob(a,b,c){var d,e,f,g,h,i,j,k,m=this,o={},p=a.style,q=a.nodeType&&W(a),r=n._data(a,"fxshow");c.queue||(h=n._queueHooks(a,"fx"),null==h.unqueued&&(h.unqueued=0,i=h.empty.fire,h.empty.fire=function(){h.unqueued||i()}),h.unqueued++,m.always(function(){m.always(function(){h.unqueued--,n.queue(a,"fx").length||h.empty.fire()})})),1===a.nodeType&&("height"in b||"width"in b)&&(c.overflow=[p.overflow,p.overflowX,p.overflowY],j=n.css(a,"display"),k="none"===j?n._data(a,"olddisplay")||Ma(a.nodeName):j,"inline"===k&&"none"===n.css(a,"float")&&(l.inlineBlockNeedsLayout&&"inline"!==Ma(a.nodeName)?p.zoom=1:p.display="inline-block")),c.overflow&&(p.overflow="hidden",l.shrinkWrapBlocks()||m.always(function(){p.overflow=c.overflow[0],p.overflowX=c.overflow[1],p.overflowY=c.overflow[2]}));for(d in b)if(e=b[d],jb.exec(e)){if(delete b[d],f=f||"toggle"===e,e===(q?"hide":"show")){if("show"!==e||!r||void 0===r[d])continue;q=!0}o[d]=r&&r[d]||n.style(a,d)}else j=void 0;if(n.isEmptyObject(o))"inline"===("none"===j?Ma(a.nodeName):j)&&(p.display=j);else{r?"hidden"in r&&(q=r.hidden):r=n._data(a,"fxshow",{}),f&&(r.hidden=!q),q?n(a).show():m.done(function(){n(a).hide()}),m.done(function(){var b;n._removeData(a,"fxshow");for(b in o)n.style(a,b,o[b])});for(d in o)g=nb(q?r[d]:0,d,m),d in r||(r[d]=g.start,q&&(g.end=g.start,g.start="width"===d||"height"===d?1:0))}}function pb(a,b){var c,d,e,f,g;for(c in a)if(d=n.camelCase(c),e=b[d],f=a[c],n.isArray(f)&&(e=f[1],f=a[c]=f[0]),c!==d&&(a[d]=f,delete a[c]),g=n.cssHooks[d],g&&"expand"in g){f=g.expand(f),delete a[d];for(c in f)c in a||(a[c]=f[c],b[c]=e)}else b[d]=e}function qb(a,b,c){var d,e,f=0,g=qb.prefilters.length,h=n.Deferred().always(function(){delete i.elem}),i=function(){if(e)return!1;for(var b=hb||lb(),c=Math.max(0,j.startTime+j.duration-b),d=c/j.duration||0,f=1-d,g=0,i=j.tweens.length;i>g;g++)j.tweens[g].run(f);return h.notifyWith(a,[j,f,c]),1>f&&i?c:(h.resolveWith(a,[j]),!1)},j=h.promise({elem:a,props:n.extend({},b),opts:n.extend(!0,{specialEasing:{},easing:n.easing._default},c),originalProperties:b,originalOptions:c,startTime:hb||lb(),duration:c.duration,tweens:[],createTween:function(b,c){var d=n.Tween(a,j.opts,b,c,j.opts.specialEasing[b]||j.opts.easing);return j.tweens.push(d),d},stop:function(b){var c=0,d=b?j.tweens.length:0;if(e)return this;for(e=!0;d>c;c++)j.tweens[c].run(1);return b?(h.notifyWith(a,[j,1,0]),h.resolveWith(a,[j,b])):h.rejectWith(a,[j,b]),this}}),k=j.props;for(pb(k,j.opts.specialEasing);g>f;f++)if(d=qb.prefilters[f].call(j,a,k,j.opts))return n.isFunction(d.stop)&&(n._queueHooks(j.elem,j.opts.queue).stop=n.proxy(d.stop,d)),d;return n.map(k,nb,j),n.isFunction(j.opts.start)&&j.opts.start.call(a,j),n.fx.timer(n.extend(i,{elem:a,anim:j,queue:j.opts.queue})),j.progress(j.opts.progress).done(j.opts.done,j.opts.complete).fail(j.opts.fail).always(j.opts.always)}n.Animation=n.extend(qb,{tweeners:{"*":[function(a,b){var c=this.createTween(a,b);return X(c.elem,a,U.exec(b),c),c}]},tweener:function(a,b){n.isFunction(a)?(b=a,a=["*"]):a=a.match(G);for(var c,d=0,e=a.length;e>d;d++)c=a[d],qb.tweeners[c]=qb.tweeners[c]||[],qb.tweeners[c].unshift(b)},prefilters:[ob],prefilter:function(a,b){b?qb.prefilters.unshift(a):qb.prefilters.push(a)}}),n.speed=function(a,b,c){var d=a&&"object"==typeof a?n.extend({},a):{complete:c||!c&&b||n.isFunction(a)&&a,duration:a,easing:c&&b||b&&!n.isFunction(b)&&b};return d.duration=n.fx.off?0:"number"==typeof d.duration?d.duration:d.duration in n.fx.speeds?n.fx.speeds[d.duration]:n.fx.speeds._default,null!=d.queue&&d.queue!==!0||(d.queue="fx"),d.old=d.complete,d.complete=function(){n.isFunction(d.old)&&d.old.call(this),d.queue&&n.dequeue(this,d.queue)},d},n.fn.extend({fadeTo:function(a,b,c,d){return this.filter(W).css("opacity",0).show().end().animate({opacity:b},a,c,d)},animate:function(a,b,c,d){var e=n.isEmptyObject(a),f=n.speed(b,c,d),g=function(){var b=qb(this,n.extend({},a),f);(e||n._data(this,"finish"))&&b.stop(!0)};return g.finish=g,e||f.queue===!1?this.each(g):this.queue(f.queue,g)},stop:function(a,b,c){var d=function(a){var b=a.stop;delete a.stop,b(c)};return"string"!=typeof a&&(c=b,b=a,a=void 0),b&&a!==!1&&this.queue(a||"fx",[]),this.each(function(){var b=!0,e=null!=a&&a+"queueHooks",f=n.timers,g=n._data(this);if(e)g[e]&&g[e].stop&&d(g[e]);else for(e in g)g[e]&&g[e].stop&&kb.test(e)&&d(g[e]);for(e=f.length;e--;)f[e].elem!==this||null!=a&&f[e].queue!==a||(f[e].anim.stop(c),b=!1,f.splice(e,1));!b&&c||n.dequeue(this,a)})},finish:function(a){return a!==!1&&(a=a||"fx"),this.each(function(){var b,c=n._data(this),d=c[a+"queue"],e=c[a+"queueHooks"],f=n.timers,g=d?d.length:0;for(c.finish=!0,n.queue(this,a,[]),e&&e.stop&&e.stop.call(this,!0),b=f.length;b--;)f[b].elem===this&&f[b].queue===a&&(f[b].anim.stop(!0),f.splice(b,1));for(b=0;g>b;b++)d[b]&&d[b].finish&&d[b].finish.call(this);delete c.finish})}}),n.each(["toggle","show","hide"],function(a,b){var c=n.fn[b];n.fn[b]=function(a,d,e){return null==a||"boolean"==typeof a?c.apply(this,arguments):this.animate(mb(b,!0),a,d,e)}}),n.each({slideDown:mb("show"),slideUp:mb("hide"),slideToggle:mb("toggle"),fadeIn:{opacity:"show"},fadeOut:{opacity:"hide"},fadeToggle:{opacity:"toggle"}},function(a,b){n.fn[a]=function(a,c,d){return this.animate(b,a,c,d)}}),n.timers=[],n.fx.tick=function(){var a,b=n.timers,c=0;for(hb=n.now();c<b.length;c++)a=b[c],a()||b[c]!==a||b.splice(c--,1);b.length||n.fx.stop(),hb=void 0},n.fx.timer=function(a){n.timers.push(a),a()?n.fx.start():n.timers.pop()},n.fx.interval=13,n.fx.start=function(){ib||(ib=a.setInterval(n.fx.tick,n.fx.interval))},n.fx.stop=function(){a.clearInterval(ib),ib=null},n.fx.speeds={slow:600,fast:200,_default:400},n.fn.delay=function(b,c){return b=n.fx?n.fx.speeds[b]||b:b,c=c||"fx",this.queue(c,function(c,d){var e=a.setTimeout(c,b);d.stop=function(){a.clearTimeout(e)}})},function(){var a,b=d.createElement("input"),c=d.createElement("div"),e=d.createElement("select"),f=e.appendChild(d.createElement("option"));c=d.createElement("div"),c.setAttribute("className","t"),c.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",a=c.getElementsByTagName("a")[0],b.setAttribute("type","checkbox"),c.appendChild(b),a=c.getElementsByTagName("a")[0],a.style.cssText="top:1px",l.getSetAttribute="t"!==c.className,l.style=/top/.test(a.getAttribute("style")),l.hrefNormalized="/a"===a.getAttribute("href"),l.checkOn=!!b.value,l.optSelected=f.selected,l.enctype=!!d.createElement("form").enctype,e.disabled=!0,l.optDisabled=!f.disabled,b=d.createElement("input"),b.setAttribute("value",""),l.input=""===b.getAttribute("value"),b.value="t",b.setAttribute("type","radio"),l.radioValue="t"===b.value}();var rb=/\r/g,sb=/[\x20\t\r\n\f]+/g;n.fn.extend({val:function(a){var b,c,d,e=this[0];{if(arguments.length)return d=n.isFunction(a),this.each(function(c){var e;1===this.nodeType&&(e=d?a.call(this,c,n(this).val()):a,null==e?e="":"number"==typeof e?e+="":n.isArray(e)&&(e=n.map(e,function(a){return null==a?"":a+""})),b=n.valHooks[this.type]||n.valHooks[this.nodeName.toLowerCase()],b&&"set"in b&&void 0!==b.set(this,e,"value")||(this.value=e))});if(e)return b=n.valHooks[e.type]||n.valHooks[e.nodeName.toLowerCase()],b&&"get"in b&&void 0!==(c=b.get(e,"value"))?c:(c=e.value,"string"==typeof c?c.replace(rb,""):null==c?"":c)}}}),n.extend({valHooks:{option:{get:function(a){var b=n.find.attr(a,"value");return null!=b?b:n.trim(n.text(a)).replace(sb," ")}},select:{get:function(a){for(var b,c,d=a.options,e=a.selectedIndex,f="select-one"===a.type||0>e,g=f?null:[],h=f?e+1:d.length,i=0>e?h:f?e:0;h>i;i++)if(c=d[i],(c.selected||i===e)&&(l.optDisabled?!c.disabled:null===c.getAttribute("disabled"))&&(!c.parentNode.disabled||!n.nodeName(c.parentNode,"optgroup"))){if(b=n(c).val(),f)return b;g.push(b)}return g},set:function(a,b){var c,d,e=a.options,f=n.makeArray(b),g=e.length;while(g--)if(d=e[g],n.inArray(n.valHooks.option.get(d),f)>-1)try{d.selected=c=!0}catch(h){d.scrollHeight}else d.selected=!1;return c||(a.selectedIndex=-1),e}}}}),n.each(["radio","checkbox"],function(){n.valHooks[this]={set:function(a,b){return n.isArray(b)?a.checked=n.inArray(n(a).val(),b)>-1:void 0}},l.checkOn||(n.valHooks[this].get=function(a){return null===a.getAttribute("value")?"on":a.value})});var tb,ub,vb=n.expr.attrHandle,wb=/^(?:checked|selected)$/i,xb=l.getSetAttribute,yb=l.input;n.fn.extend({attr:function(a,b){return Y(this,n.attr,a,b,arguments.length>1)},removeAttr:function(a){return this.each(function(){n.removeAttr(this,a)})}}),n.extend({attr:function(a,b,c){var d,e,f=a.nodeType;if(3!==f&&8!==f&&2!==f)return"undefined"==typeof a.getAttribute?n.prop(a,b,c):(1===f&&n.isXMLDoc(a)||(b=b.toLowerCase(),e=n.attrHooks[b]||(n.expr.match.bool.test(b)?ub:tb)),void 0!==c?null===c?void n.removeAttr(a,b):e&&"set"in e&&void 0!==(d=e.set(a,c,b))?d:(a.setAttribute(b,c+""),c):e&&"get"in e&&null!==(d=e.get(a,b))?d:(d=n.find.attr(a,b),null==d?void 0:d))},attrHooks:{type:{set:function(a,b){if(!l.radioValue&&"radio"===b&&n.nodeName(a,"input")){var c=a.value;return a.setAttribute("type",b),c&&(a.value=c),b}}}},removeAttr:function(a,b){var c,d,e=0,f=b&&b.match(G);if(f&&1===a.nodeType)while(c=f[e++])d=n.propFix[c]||c,n.expr.match.bool.test(c)?yb&&xb||!wb.test(c)?a[d]=!1:a[n.camelCase("default-"+c)]=a[d]=!1:n.attr(a,c,""),a.removeAttribute(xb?c:d)}}),ub={set:function(a,b,c){return b===!1?n.removeAttr(a,c):yb&&xb||!wb.test(c)?a.setAttribute(!xb&&n.propFix[c]||c,c):a[n.camelCase("default-"+c)]=a[c]=!0,c}},n.each(n.expr.match.bool.source.match(/\w+/g),function(a,b){var c=vb[b]||n.find.attr;yb&&xb||!wb.test(b)?vb[b]=function(a,b,d){var e,f;return d||(f=vb[b],vb[b]=e,e=null!=c(a,b,d)?b.toLowerCase():null,vb[b]=f),e}:vb[b]=function(a,b,c){return c?void 0:a[n.camelCase("default-"+b)]?b.toLowerCase():null}}),yb&&xb||(n.attrHooks.value={set:function(a,b,c){return n.nodeName(a,"input")?void(a.defaultValue=b):tb&&tb.set(a,b,c)}}),xb||(tb={set:function(a,b,c){var d=a.getAttributeNode(c);return d||a.setAttributeNode(d=a.ownerDocument.createAttribute(c)),d.value=b+="","value"===c||b===a.getAttribute(c)?b:void 0}},vb.id=vb.name=vb.coords=function(a,b,c){var d;return c?void 0:(d=a.getAttributeNode(b))&&""!==d.value?d.value:null},n.valHooks.button={get:function(a,b){var c=a.getAttributeNode(b);return c&&c.specified?c.value:void 0},set:tb.set},n.attrHooks.contenteditable={set:function(a,b,c){tb.set(a,""===b?!1:b,c)}},n.each(["width","height"],function(a,b){n.attrHooks[b]={set:function(a,c){return""===c?(a.setAttribute(b,"auto"),c):void 0}}})),l.style||(n.attrHooks.style={get:function(a){return a.style.cssText||void 0},set:function(a,b){return a.style.cssText=b+""}});var zb=/^(?:input|select|textarea|button|object)$/i,Ab=/^(?:a|area)$/i;n.fn.extend({prop:function(a,b){return Y(this,n.prop,a,b,arguments.length>1)},removeProp:function(a){return a=n.propFix[a]||a,this.each(function(){try{this[a]=void 0,delete this[a]}catch(b){}})}}),n.extend({prop:function(a,b,c){var d,e,f=a.nodeType;if(3!==f&&8!==f&&2!==f)return 1===f&&n.isXMLDoc(a)||(b=n.propFix[b]||b,e=n.propHooks[b]),void 0!==c?e&&"set"in e&&void 0!==(d=e.set(a,c,b))?d:a[b]=c:e&&"get"in e&&null!==(d=e.get(a,b))?d:a[b]},propHooks:{tabIndex:{get:function(a){var b=n.find.attr(a,"tabindex");return b?parseInt(b,10):zb.test(a.nodeName)||Ab.test(a.nodeName)&&a.href?0:-1}}},propFix:{"for":"htmlFor","class":"className"}}),l.hrefNormalized||n.each(["href","src"],function(a,b){n.propHooks[b]={get:function(a){return a.getAttribute(b,4)}}}),l.optSelected||(n.propHooks.selected={get:function(a){var b=a.parentNode;return b&&(b.selectedIndex,b.parentNode&&b.parentNode.selectedIndex),null},set:function(a){var b=a.parentNode;b&&(b.selectedIndex,b.parentNode&&b.parentNode.selectedIndex)}}),n.each(["tabIndex","readOnly","maxLength","cellSpacing","cellPadding","rowSpan","colSpan","useMap","frameBorder","contentEditable"],function(){n.propFix[this.toLowerCase()]=this}),l.enctype||(n.propFix.enctype="encoding");var Bb=/[\t\r\n\f]/g;function Cb(a){return n.attr(a,"class")||""}n.fn.extend({addClass:function(a){var b,c,d,e,f,g,h,i=0;if(n.isFunction(a))return this.each(function(b){n(this).addClass(a.call(this,b,Cb(this)))});if("string"==typeof a&&a){b=a.match(G)||[];while(c=this[i++])if(e=Cb(c),d=1===c.nodeType&&(" "+e+" ").replace(Bb," ")){g=0;while(f=b[g++])d.indexOf(" "+f+" ")<0&&(d+=f+" ");h=n.trim(d),e!==h&&n.attr(c,"class",h)}}return this},removeClass:function(a){var b,c,d,e,f,g,h,i=0;if(n.isFunction(a))return this.each(function(b){n(this).removeClass(a.call(this,b,Cb(this)))});if(!arguments.length)return this.attr("class","");if("string"==typeof a&&a){b=a.match(G)||[];while(c=this[i++])if(e=Cb(c),d=1===c.nodeType&&(" "+e+" ").replace(Bb," ")){g=0;while(f=b[g++])while(d.indexOf(" "+f+" ")>-1)d=d.replace(" "+f+" "," ");h=n.trim(d),e!==h&&n.attr(c,"class",h)}}return this},toggleClass:function(a,b){var c=typeof a;return"boolean"==typeof b&&"string"===c?b?this.addClass(a):this.removeClass(a):n.isFunction(a)?this.each(function(c){n(this).toggleClass(a.call(this,c,Cb(this),b),b)}):this.each(function(){var b,d,e,f;if("string"===c){d=0,e=n(this),f=a.match(G)||[];while(b=f[d++])e.hasClass(b)?e.removeClass(b):e.addClass(b)}else void 0!==a&&"boolean"!==c||(b=Cb(this),b&&n._data(this,"__className__",b),n.attr(this,"class",b||a===!1?"":n._data(this,"__className__")||""))})},hasClass:function(a){var b,c,d=0;b=" "+a+" ";while(c=this[d++])if(1===c.nodeType&&(" "+Cb(c)+" ").replace(Bb," ").indexOf(b)>-1)return!0;return!1}}),n.each("blur focus focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select submit keydown keypress keyup error contextmenu".split(" "),function(a,b){n.fn[b]=function(a,c){return arguments.length>0?this.on(b,null,a,c):this.trigger(b)}}),n.fn.extend({hover:function(a,b){return this.mouseenter(a).mouseleave(b||a)}});var Db=a.location,Eb=n.now(),Fb=/\?/,Gb=/(,)|(\[|{)|(}|])|"(?:[^"\\\r\n]|\\["\\\/bfnrt]|\\u[\da-fA-F]{4})*"\s*:?|true|false|null|-?(?!0\d)\d+(?:\.\d+|)(?:[eE][+-]?\d+|)/g;n.parseJSON=function(b){if(a.JSON&&a.JSON.parse)return a.JSON.parse(b+"");var c,d=null,e=n.trim(b+"");return e&&!n.trim(e.replace(Gb,function(a,b,e,f){return c&&b&&(d=0),0===d?a:(c=e||b,d+=!f-!e,"")}))?Function("return "+e)():n.error("Invalid JSON: "+b)},n.parseXML=function(b){var c,d;if(!b||"string"!=typeof b)return null;try{a.DOMParser?(d=new a.DOMParser,c=d.parseFromString(b,"text/xml")):(c=new a.ActiveXObject("Microsoft.XMLDOM"),c.async="false",c.loadXML(b))}catch(e){c=void 0}return c&&c.documentElement&&!c.getElementsByTagName("parsererror").length||n.error("Invalid XML: "+b),c};var Hb=/#.*$/,Ib=/([?&])_=[^&]*/,Jb=/^(.*?):[ \t]*([^\r\n]*)\r?$/gm,Kb=/^(?:about|app|app-storage|.+-extension|file|res|widget):$/,Lb=/^(?:GET|HEAD)$/,Mb=/^\/\//,Nb=/^([\w.+-]+:)(?:\/\/(?:[^\/?#]*@|)([^\/?#:]*)(?::(\d+)|)|)/,Ob={},Pb={},Qb="*/".concat("*"),Rb=Db.href,Sb=Nb.exec(Rb.toLowerCase())||[];function Tb(a){return function(b,c){"string"!=typeof b&&(c=b,b="*");var d,e=0,f=b.toLowerCase().match(G)||[];if(n.isFunction(c))while(d=f[e++])"+"===d.charAt(0)?(d=d.slice(1)||"*",(a[d]=a[d]||[]).unshift(c)):(a[d]=a[d]||[]).push(c)}}function Ub(a,b,c,d){var e={},f=a===Pb;function g(h){var i;return e[h]=!0,n.each(a[h]||[],function(a,h){var j=h(b,c,d);return"string"!=typeof j||f||e[j]?f?!(i=j):void 0:(b.dataTypes.unshift(j),g(j),!1)}),i}return g(b.dataTypes[0])||!e["*"]&&g("*")}function Vb(a,b){var c,d,e=n.ajaxSettings.flatOptions||{};for(d in b)void 0!==b[d]&&((e[d]?a:c||(c={}))[d]=b[d]);return c&&n.extend(!0,a,c),a}function Wb(a,b,c){var d,e,f,g,h=a.contents,i=a.dataTypes;while("*"===i[0])i.shift(),void 0===e&&(e=a.mimeType||b.getResponseHeader("Content-Type"));if(e)for(g in h)if(h[g]&&h[g].test(e)){i.unshift(g);break}if(i[0]in c)f=i[0];else{for(g in c){if(!i[0]||a.converters[g+" "+i[0]]){f=g;break}d||(d=g)}f=f||d}return f?(f!==i[0]&&i.unshift(f),c[f]):void 0}function Xb(a,b,c,d){var e,f,g,h,i,j={},k=a.dataTypes.slice();if(k[1])for(g in a.converters)j[g.toLowerCase()]=a.converters[g];f=k.shift();while(f)if(a.responseFields[f]&&(c[a.responseFields[f]]=b),!i&&d&&a.dataFilter&&(b=a.dataFilter(b,a.dataType)),i=f,f=k.shift())if("*"===f)f=i;else if("*"!==i&&i!==f){if(g=j[i+" "+f]||j["* "+f],!g)for(e in j)if(h=e.split(" "),h[1]===f&&(g=j[i+" "+h[0]]||j["* "+h[0]])){g===!0?g=j[e]:j[e]!==!0&&(f=h[0],k.unshift(h[1]));break}if(g!==!0)if(g&&a["throws"])b=g(b);else try{b=g(b)}catch(l){return{state:"parsererror",error:g?l:"No conversion from "+i+" to "+f}}}return{state:"success",data:b}}n.extend({active:0,lastModified:{},etag:{},ajaxSettings:{url:Rb,type:"GET",isLocal:Kb.test(Sb[1]),global:!0,processData:!0,async:!0,contentType:"application/x-www-form-urlencoded; charset=UTF-8",accepts:{"*":Qb,text:"text/plain",html:"text/html",xml:"application/xml, text/xml",json:"application/json, text/javascript"},contents:{xml:/\bxml\b/,html:/\bhtml/,json:/\bjson\b/},responseFields:{xml:"responseXML",text:"responseText",json:"responseJSON"},converters:{"* text":String,"text html":!0,"text json":n.parseJSON,"text xml":n.parseXML},flatOptions:{url:!0,context:!0}},ajaxSetup:function(a,b){return b?Vb(Vb(a,n.ajaxSettings),b):Vb(n.ajaxSettings,a)},ajaxPrefilter:Tb(Ob),ajaxTransport:Tb(Pb),ajax:function(b,c){"object"==typeof b&&(c=b,b=void 0),c=c||{};var d,e,f,g,h,i,j,k,l=n.ajaxSetup({},c),m=l.context||l,o=l.context&&(m.nodeType||m.jquery)?n(m):n.event,p=n.Deferred(),q=n.Callbacks("once memory"),r=l.statusCode||{},s={},t={},u=0,v="canceled",w={readyState:0,getResponseHeader:function(a){var b;if(2===u){if(!k){k={};while(b=Jb.exec(g))k[b[1].toLowerCase()]=b[2]}b=k[a.toLowerCase()]}return null==b?null:b},getAllResponseHeaders:function(){return 2===u?g:null},setRequestHeader:function(a,b){var c=a.toLowerCase();return u||(a=t[c]=t[c]||a,s[a]=b),this},overrideMimeType:function(a){return u||(l.mimeType=a),this},statusCode:function(a){var b;if(a)if(2>u)for(b in a)r[b]=[r[b],a[b]];else w.always(a[w.status]);return this},abort:function(a){var b=a||v;return j&&j.abort(b),y(0,b),this}};if(p.promise(w).complete=q.add,w.success=w.done,w.error=w.fail,l.url=((b||l.url||Rb)+"").replace(Hb,"").replace(Mb,Sb[1]+"//"),l.type=c.method||c.type||l.method||l.type,l.dataTypes=n.trim(l.dataType||"*").toLowerCase().match(G)||[""],null==l.crossDomain&&(d=Nb.exec(l.url.toLowerCase()),l.crossDomain=!(!d||d[1]===Sb[1]&&d[2]===Sb[2]&&(d[3]||("http:"===d[1]?"80":"443"))===(Sb[3]||("http:"===Sb[1]?"80":"443")))),l.data&&l.processData&&"string"!=typeof l.data&&(l.data=n.param(l.data,l.traditional)),Ub(Ob,l,c,w),2===u)return w;i=n.event&&l.global,i&&0===n.active++&&n.event.trigger("ajaxStart"),l.type=l.type.toUpperCase(),l.hasContent=!Lb.test(l.type),f=l.url,l.hasContent||(l.data&&(f=l.url+=(Fb.test(f)?"&":"?")+l.data,delete l.data),l.cache===!1&&(l.url=Ib.test(f)?f.replace(Ib,"$1_="+Eb++):f+(Fb.test(f)?"&":"?")+"_="+Eb++)),l.ifModified&&(n.lastModified[f]&&w.setRequestHeader("If-Modified-Since",n.lastModified[f]),n.etag[f]&&w.setRequestHeader("If-None-Match",n.etag[f])),(l.data&&l.hasContent&&l.contentType!==!1||c.contentType)&&w.setRequestHeader("Content-Type",l.contentType),w.setRequestHeader("Accept",l.dataTypes[0]&&l.accepts[l.dataTypes[0]]?l.accepts[l.dataTypes[0]]+("*"!==l.dataTypes[0]?", "+Qb+"; q=0.01":""):l.accepts["*"]);for(e in l.headers)w.setRequestHeader(e,l.headers[e]);if(l.beforeSend&&(l.beforeSend.call(m,w,l)===!1||2===u))return w.abort();v="abort";for(e in{success:1,error:1,complete:1})w[e](l[e]);if(j=Ub(Pb,l,c,w)){if(w.readyState=1,i&&o.trigger("ajaxSend",[w,l]),2===u)return w;l.async&&l.timeout>0&&(h=a.setTimeout(function(){w.abort("timeout")},l.timeout));try{u=1,j.send(s,y)}catch(x){if(!(2>u))throw x;y(-1,x)}}else y(-1,"No Transport");function y(b,c,d,e){var k,s,t,v,x,y=c;2!==u&&(u=2,h&&a.clearTimeout(h),j=void 0,g=e||"",w.readyState=b>0?4:0,k=b>=200&&300>b||304===b,d&&(v=Wb(l,w,d)),v=Xb(l,v,w,k),k?(l.ifModified&&(x=w.getResponseHeader("Last-Modified"),x&&(n.lastModified[f]=x),x=w.getResponseHeader("etag"),x&&(n.etag[f]=x)),204===b||"HEAD"===l.type?y="nocontent":304===b?y="notmodified":(y=v.state,s=v.data,t=v.error,k=!t)):(t=y,!b&&y||(y="error",0>b&&(b=0))),w.status=b,w.statusText=(c||y)+"",k?p.resolveWith(m,[s,y,w]):p.rejectWith(m,[w,y,t]),w.statusCode(r),r=void 0,i&&o.trigger(k?"ajaxSuccess":"ajaxError",[w,l,k?s:t]),q.fireWith(m,[w,y]),i&&(o.trigger("ajaxComplete",[w,l]),--n.active||n.event.trigger("ajaxStop")))}return w},getJSON:function(a,b,c){return n.get(a,b,c,"json")},getScript:function(a,b){return n.get(a,void 0,b,"script")}}),n.each(["get","post"],function(a,b){n[b]=function(a,c,d,e){return n.isFunction(c)&&(e=e||d,d=c,c=void 0),n.ajax(n.extend({url:a,type:b,dataType:e,data:c,success:d},n.isPlainObject(a)&&a))}}),n._evalUrl=function(a){return n.ajax({url:a,type:"GET",dataType:"script",cache:!0,async:!1,global:!1,"throws":!0})},n.fn.extend({wrapAll:function(a){if(n.isFunction(a))return this.each(function(b){n(this).wrapAll(a.call(this,b))});if(this[0]){var b=n(a,this[0].ownerDocument).eq(0).clone(!0);this[0].parentNode&&b.insertBefore(this[0]),b.map(function(){var a=this;while(a.firstChild&&1===a.firstChild.nodeType)a=a.firstChild;return a}).append(this)}return this},wrapInner:function(a){return n.isFunction(a)?this.each(function(b){n(this).wrapInner(a.call(this,b))}):this.each(function(){var b=n(this),c=b.contents();c.length?c.wrapAll(a):b.append(a)})},wrap:function(a){var b=n.isFunction(a);return this.each(function(c){n(this).wrapAll(b?a.call(this,c):a)})},unwrap:function(){return this.parent().each(function(){n.nodeName(this,"body")||n(this).replaceWith(this.childNodes)}).end()}});function Yb(a){return a.style&&a.style.display||n.css(a,"display")}function Zb(a){if(!n.contains(a.ownerDocument||d,a))return!0;while(a&&1===a.nodeType){if("none"===Yb(a)||"hidden"===a.type)return!0;a=a.parentNode}return!1}n.expr.filters.hidden=function(a){return l.reliableHiddenOffsets()?a.offsetWidth<=0&&a.offsetHeight<=0&&!a.getClientRects().length:Zb(a)},n.expr.filters.visible=function(a){return!n.expr.filters.hidden(a)};var $b=/%20/g,_b=/\[\]$/,ac=/\r?\n/g,bc=/^(?:submit|button|image|reset|file)$/i,cc=/^(?:input|select|textarea|keygen)/i;function dc(a,b,c,d){var e;if(n.isArray(b))n.each(b,function(b,e){c||_b.test(a)?d(a,e):dc(a+"["+("object"==typeof e&&null!=e?b:"")+"]",e,c,d)});else if(c||"object"!==n.type(b))d(a,b);else for(e in b)dc(a+"["+e+"]",b[e],c,d)}n.param=function(a,b){var c,d=[],e=function(a,b){b=n.isFunction(b)?b():null==b?"":b,d[d.length]=encodeURIComponent(a)+"="+encodeURIComponent(b)};if(void 0===b&&(b=n.ajaxSettings&&n.ajaxSettings.traditional),n.isArray(a)||a.jquery&&!n.isPlainObject(a))n.each(a,function(){e(this.name,this.value)});else for(c in a)dc(c,a[c],b,e);return d.join("&").replace($b,"+")},n.fn.extend({serialize:function(){return n.param(this.serializeArray())},serializeArray:function(){return this.map(function(){var a=n.prop(this,"elements");return a?n.makeArray(a):this}).filter(function(){var a=this.type;return this.name&&!n(this).is(":disabled")&&cc.test(this.nodeName)&&!bc.test(a)&&(this.checked||!Z.test(a))}).map(function(a,b){var c=n(this).val();return null==c?null:n.isArray(c)?n.map(c,function(a){return{name:b.name,value:a.replace(ac,"\r\n")}}):{name:b.name,value:c.replace(ac,"\r\n")}}).get()}}),n.ajaxSettings.xhr=void 0!==a.ActiveXObject?function(){return this.isLocal?ic():d.documentMode>8?hc():/^(get|post|head|put|delete|options)$/i.test(this.type)&&hc()||ic()}:hc;var ec=0,fc={},gc=n.ajaxSettings.xhr();a.attachEvent&&a.attachEvent("onunload",function(){for(var a in fc)fc[a](void 0,!0)}),l.cors=!!gc&&"withCredentials"in gc,gc=l.ajax=!!gc,gc&&n.ajaxTransport(function(b){if(!b.crossDomain||l.cors){var c;return{send:function(d,e){var f,g=b.xhr(),h=++ec;if(g.open(b.type,b.url,b.async,b.username,b.password),b.xhrFields)for(f in b.xhrFields)g[f]=b.xhrFields[f];b.mimeType&&g.overrideMimeType&&g.overrideMimeType(b.mimeType),b.crossDomain||d["X-Requested-With"]||(d["X-Requested-With"]="XMLHttpRequest");for(f in d)void 0!==d[f]&&g.setRequestHeader(f,d[f]+"");g.send(b.hasContent&&b.data||null),c=function(a,d){var f,i,j;if(c&&(d||4===g.readyState))if(delete fc[h],c=void 0,g.onreadystatechange=n.noop,d)4!==g.readyState&&g.abort();else{j={},f=g.status,"string"==typeof g.responseText&&(j.text=g.responseText);try{i=g.statusText}catch(k){i=""}f||!b.isLocal||b.crossDomain?1223===f&&(f=204):f=j.text?200:404}j&&e(f,i,j,g.getAllResponseHeaders())},b.async?4===g.readyState?a.setTimeout(c):g.onreadystatechange=fc[h]=c:c()},abort:function(){c&&c(void 0,!0)}}}});function hc(){try{return new a.XMLHttpRequest}catch(b){}}function ic(){try{return new a.ActiveXObject("Microsoft.XMLHTTP")}catch(b){}}n.ajaxSetup({accepts:{script:"text/javascript, application/javascript, application/ecmascript, application/x-ecmascript"},contents:{script:/\b(?:java|ecma)script\b/},converters:{"text script":function(a){return n.globalEval(a),a}}}),n.ajaxPrefilter("script",function(a){void 0===a.cache&&(a.cache=!1),a.crossDomain&&(a.type="GET",a.global=!1)}),n.ajaxTransport("script",function(a){if(a.crossDomain){var b,c=d.head||n("head")[0]||d.documentElement;return{send:function(e,f){b=d.createElement("script"),b.async=!0,a.scriptCharset&&(b.charset=a.scriptCharset),b.src=a.url,b.onload=b.onreadystatechange=function(a,c){(c||!b.readyState||/loaded|complete/.test(b.readyState))&&(b.onload=b.onreadystatechange=null,b.parentNode&&b.parentNode.removeChild(b),b=null,c||f(200,"success"))},c.insertBefore(b,c.firstChild)},abort:function(){b&&b.onload(void 0,!0)}}}});var jc=[],kc=/(=)\?(?=&|$)|\?\?/;n.ajaxSetup({jsonp:"callback",jsonpCallback:function(){var a=jc.pop()||n.expando+"_"+Eb++;return this[a]=!0,a}}),n.ajaxPrefilter("json jsonp",function(b,c,d){var e,f,g,h=b.jsonp!==!1&&(kc.test(b.url)?"url":"string"==typeof b.data&&0===(b.contentType||"").indexOf("application/x-www-form-urlencoded")&&kc.test(b.data)&&"data");return h||"jsonp"===b.dataTypes[0]?(e=b.jsonpCallback=n.isFunction(b.jsonpCallback)?b.jsonpCallback():b.jsonpCallback,h?b[h]=b[h].replace(kc,"$1"+e):b.jsonp!==!1&&(b.url+=(Fb.test(b.url)?"&":"?")+b.jsonp+"="+e),b.converters["script json"]=function(){return g||n.error(e+" was not called"),g[0]},b.dataTypes[0]="json",f=a[e],a[e]=function(){g=arguments},d.always(function(){void 0===f?n(a).removeProp(e):a[e]=f,b[e]&&(b.jsonpCallback=c.jsonpCallback,jc.push(e)),g&&n.isFunction(f)&&f(g[0]),g=f=void 0}),"script"):void 0}),n.parseHTML=function(a,b,c){if(!a||"string"!=typeof a)return null;"boolean"==typeof b&&(c=b,b=!1),b=b||d;var e=x.exec(a),f=!c&&[];return e?[b.createElement(e[1])]:(e=ja([a],b,f),f&&f.length&&n(f).remove(),n.merge([],e.childNodes))};var lc=n.fn.load;n.fn.load=function(a,b,c){if("string"!=typeof a&&lc)return lc.apply(this,arguments);var d,e,f,g=this,h=a.indexOf(" ");return h>-1&&(d=n.trim(a.slice(h,a.length)),a=a.slice(0,h)),n.isFunction(b)?(c=b,b=void 0):b&&"object"==typeof b&&(e="POST"),g.length>0&&n.ajax({url:a,type:e||"GET",dataType:"html",data:b}).done(function(a){f=arguments,g.html(d?n("<div>").append(n.parseHTML(a)).find(d):a)}).always(c&&function(a,b){g.each(function(){c.apply(this,f||[a.responseText,b,a])})}),this},n.each(["ajaxStart","ajaxStop","ajaxComplete","ajaxError","ajaxSuccess","ajaxSend"],function(a,b){n.fn[b]=function(a){return this.on(b,a)}}),n.expr.filters.animated=function(a){return n.grep(n.timers,function(b){return a===b.elem}).length};function mc(a){return n.isWindow(a)?a:9===a.nodeType?a.defaultView||a.parentWindow:!1}n.offset={setOffset:function(a,b,c){var d,e,f,g,h,i,j,k=n.css(a,"position"),l=n(a),m={};"static"===k&&(a.style.position="relative"),h=l.offset(),f=n.css(a,"top"),i=n.css(a,"left"),j=("absolute"===k||"fixed"===k)&&n.inArray("auto",[f,i])>-1,j?(d=l.position(),g=d.top,e=d.left):(g=parseFloat(f)||0,e=parseFloat(i)||0),n.isFunction(b)&&(b=b.call(a,c,n.extend({},h))),null!=b.top&&(m.top=b.top-h.top+g),null!=b.left&&(m.left=b.left-h.left+e),"using"in b?b.using.call(a,m):l.css(m)}},n.fn.extend({offset:function(a){if(arguments.length)return void 0===a?this:this.each(function(b){n.offset.setOffset(this,a,b)});var b,c,d={top:0,left:0},e=this[0],f=e&&e.ownerDocument;if(f)return b=f.documentElement,n.contains(b,e)?("undefined"!=typeof e.getBoundingClientRect&&(d=e.getBoundingClientRect()),c=mc(f),{top:d.top+(c.pageYOffset||b.scrollTop)-(b.clientTop||0),left:d.left+(c.pageXOffset||b.scrollLeft)-(b.clientLeft||0)}):d},position:function(){if(this[0]){var a,b,c={top:0,left:0},d=this[0];return"fixed"===n.css(d,"position")?b=d.getBoundingClientRect():(a=this.offsetParent(),b=this.offset(),n.nodeName(a[0],"html")||(c=a.offset()),c.top+=n.css(a[0],"borderTopWidth",!0),c.left+=n.css(a[0],"borderLeftWidth",!0)),{top:b.top-c.top-n.css(d,"marginTop",!0),left:b.left-c.left-n.css(d,"marginLeft",!0)}}},offsetParent:function(){return this.map(function(){var a=this.offsetParent;while(a&&!n.nodeName(a,"html")&&"static"===n.css(a,"position"))a=a.offsetParent;return a||Qa})}}),n.each({scrollLeft:"pageXOffset",scrollTop:"pageYOffset"},function(a,b){var c=/Y/.test(b);n.fn[a]=function(d){return Y(this,function(a,d,e){var f=mc(a);return void 0===e?f?b in f?f[b]:f.document.documentElement[d]:a[d]:void(f?f.scrollTo(c?n(f).scrollLeft():e,c?e:n(f).scrollTop()):a[d]=e)},a,d,arguments.length,null)}}),n.each(["top","left"],function(a,b){n.cssHooks[b]=Ua(l.pixelPosition,function(a,c){return c?(c=Sa(a,b),Oa.test(c)?n(a).position()[b]+"px":c):void 0})}),n.each({Height:"height",Width:"width"},function(a,b){n.each({
padding:"inner"+a,content:b,"":"outer"+a},function(c,d){n.fn[d]=function(d,e){var f=arguments.length&&(c||"boolean"!=typeof d),g=c||(d===!0||e===!0?"margin":"border");return Y(this,function(b,c,d){var e;return n.isWindow(b)?b.document.documentElement["client"+a]:9===b.nodeType?(e=b.documentElement,Math.max(b.body["scroll"+a],e["scroll"+a],b.body["offset"+a],e["offset"+a],e["client"+a])):void 0===d?n.css(b,c,g):n.style(b,c,d,g)},b,f?d:void 0,f,null)}})}),n.fn.extend({bind:function(a,b,c){return this.on(a,null,b,c)},unbind:function(a,b){return this.off(a,null,b)},delegate:function(a,b,c,d){return this.on(b,a,c,d)},undelegate:function(a,b,c){return 1===arguments.length?this.off(a,"**"):this.off(b,a||"**",c)}}),n.fn.size=function(){return this.length},n.fn.andSelf=n.fn.addBack,"function"==typeof define&&define.amd&&define("jquery",[],function(){return n});var nc=a.jQuery,oc=a.$;return n.noConflict=function(b){return a.$===n&&(a.$=oc),b&&a.jQuery===n&&(a.jQuery=nc),n},b||(a.jQuery=a.$=n),n});
/*******************************************************************************
88888888ba  88888888ba  88888888888 88888888888
88      "8b 88      "8b 88          88
88      ,8P 88      ,8P 88          88
88aaaaaa8P' 88aaaaaa8P' 88aaaaa     88aaaaa
88""""""'   88""""88'   88"""""     88"""""
88          88    `8b   88          88
88          88     `8b  88          88
88          88      `8b 88888888888 88
*******************************************************************************/

var refreshPage      = 1;
var cmdPaneState     = 0;
var curRefreshVal    = 0;
var additionalParams = new Object();
var removeParams     = new Object();
var scrollToPos      = 0;
var refreshTimer;
var backendSelTimer;
var lastRowSelected;
var lastRowHighlighted;
var verifyTimer;
var iPhone           = false;
if(window.navigator && window.navigator.userAgent) {
    iPhone           = window.navigator.userAgent.match(/iPhone|iPad/i) ? true : false;
}

// needed to keep the order
var hoststatustypes    = new Array( 1, 2, 4, 8 );
var servicestatustypes = new Array( 1, 2, 4, 8, 16 );
var hostprops          = new Array( 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432 );
var serviceprops       = new Array( 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432 );

/*******************************************************************************
  ,ad8888ba,  88888888888 888b      88 88888888888 88888888ba  88   ,ad8888ba,
 d8"'    `"8b 88          8888b     88 88          88      "8b 88  d8"'    `"8b
d8'           88          88 `8b    88 88          88      ,8P 88 d8'
88            88aaaaa     88  `8b   88 88aaaaa     88aaaaaa8P' 88 88
88      88888 88"""""     88   `8b  88 88"""""     88""""88'   88 88
Y8,        88 88          88    `8b 88 88          88    `8b   88 Y8,
 Y8a.    .a88 88          88     `8888 88          88     `8b  88  Y8a.    .a8P
  `"Y88888P"  88888888888 88      `888 88888888888 88      `8b 88   `"Y8888Y"'
*******************************************************************************/

/* send debug output to firebug console */
var debug = function(str) {}
if(typeof thruk_debug_js !== 'undefined' && thruk_debug_js != undefined && thruk_debug_js) {
    if(typeof window.console === "object" && window.console.debug) {
        /* overwrite debug function, so caller information is not replaced */
        debug = window.console.debug.bind(console);
    }
}

window.addEventListener('load', function(evt) {
    try {
        if(top.frames && top.frames['side']) {
            top.frames['side'].is_reloading = false;
        }
    }
    catch(err) { debug(err); }
}, false);

/* do initial things */
function init_page() {
    jQuery('input.deletable').wrap('<span class="deleteicon" />').after(jQuery('<span/>').click(function() {
        jQuery(this).prev('input').val('').focus();
    }));

    // init some buttons
    if(has_jquery_ui) {
        jQuery('BUTTON.thruk_button').button();
        jQuery('A.thruk_button').button();
        jQuery('INPUT.thruk_button').button();

        jQuery('.thruk_button_refresh').button({
            icons: {primary: 'ui-refresh-button'}
        });
        jQuery('.thruk_button_add').button({
            icons: {primary: 'ui-add-button'}
        });
        jQuery('.thruk_button_save').button({
            icons: {primary: 'ui-save-button'}
        });

        jQuery('.thruk_radioset').buttonset();

        /* list wizard */
        jQuery('button.members_wzd_button').button({
            icons: {primary: 'ui-wzd-button'},
            text: false,
            label: 'open list wizard'
        }).click(function() {
            init_tool_list_wizard(this.id, this.name);
            return false;
        });
    }

    var newUrl = window.location.href;
    var scroll = newUrl.match(/(\?|\&)scrollTo=([\d\.]+)/);
    if(scroll) {
        scrollToPos = scroll[2];
    }

    var saved_hash = readCookie('thruk_preserve_hash');
    if(saved_hash != undefined) {
        set_hash(saved_hash);
        cookieRemove('thruk_preserve_hash');
    }

    // add title for things that might overflow
    jQuery(document).on('mouseenter', '.mightOverflow', function() {
      var This = jQuery(this);
      var title = This.attr('title');
      if(!title) {
        if(this.offsetWidth < this.scrollWidth) {
          This.attr('title', This.text().replace(/<\!\-\-[\s\S]*\-\->/, '').replace(/^\s*/, '').replace(/\s*$/, ''));
        }
      } else {
        if(this.offsetWidth >= this.scrollWidth && title == This.text()) {
          This.removeAttr('title');
        }
      }
    });

    // store browsers timezone in a cookie so we can use it in later requests
    cookieSave("thruk_tz", getBrowserTimezone());

    cleanUnderscoreUrl();
}

function getBrowserTimezone() {
    var timezone;
    try {
        if(Intl.DateTimeFormat().resolvedOptions().timeZone) {
            timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        } else {
            var offset = (new Date()).getTimezoneOffset()/60;
            if(offset == 0) {
                timezone = "UTC";
            }
            if(offset < 0) {
                timezone = "UTC"+offset;
            }
            if(offset > 0) {
                timezone = "UTC+"+offset;
            }
        }
    } catch(e) {}
    return(timezone);
}

function thruk_onerror(msg, url, line, col, error) {
  if(error_count > 5) {
    debug("too many errors, not logging any more...");
    window.onerror = undefined;
  }
  try {
    thruk_errors.unshift("Url: "+url+" Line "+line+"\nError: " + msg);
    // hide errors from saved pages
    if(window.location.protocol != 'http:' && window.location.protocol != 'https:') { return false; }
    // hide errors in line 0
    if(line == 0) { return false; }
    // hide errors from plugins and addons
    if(url.match(/^chrome:/)) { return false; }
    // skip some errors
    var skip = false;
    for(var nr = 0; nr < skip_js_errors.length; nr++) {
        if(msg.match(skip_js_errors[nr])) { skip = true; }
    }
    if(skip) { return; }
    error_count++;
    var text = getErrorText(thruk_debug_details, error);
    if(show_error_reports == "server" || show_error_reports == "both") {
        sendJSError(url_prefix+"cgi-bin/remote.cgi?log", text);
    }
    if(show_error_reports == "1" || show_error_reports == "both") {
        showBugReport('bug_report', text);
    }
  }
  catch(e) { debug(e); }
  return false;
}

/* remove ugly ?_=... from url */
function cleanUnderscoreUrl() {
    var newUrl = window.location.href;
    if (history.replaceState) {
        newUrl = cleanUnderscore(newUrl);
        try {
            history.replaceState({}, "", newUrl);
        } catch(err) { debug(err) }
    }
}

function cleanUnderscore(str) {
    str = str.replace(/\?_=\d+/g, '?');
    str = str.replace(/\&_=\d+/g, '');
    str = str.replace(/\?scrollTo=[\d\.]+/g, '?');
    str = str.replace(/\&scrollTo=[\d\.]+/g, '');
    str = str.replace(/\?autoShow=\w+/g, '?');
    str = str.replace(/\&autoShow=\w+/g, '');
    str = str.replace(/\?$/g, '');
    str = str.replace(/\?&/g, '?');
    return(str);
}

function bodyOnLoad(refresh) {
    if(scrollToPos > 0) {
        window.scroll(0, scrollToPos);
        scrollToPos = 0;
    }
    if(refresh) {
        if(window.parent && window.parent.location && String(window.parent.location.href).match(/\/panorama\.cgi/)) {
            stopRefresh();
        } else if(String(window.location.href).match(/\/panorama\.cgi/)) {
            stopRefresh();
        } else {
            setRefreshRate(refresh);
            jQuery(document).bind("mousemove click keyup", updateLastUserInteraction);
        }
    }

    init_page();
}

var lastUserInteraction;
function updateLastUserInteraction() {
    lastUserInteraction = (new Date()).getTime();
}

/* save scroll value */
function saveScroll() {
    var scroll = getPageScroll();
    if(scroll > 0) {
        additionalParams['scrollTo'] = scroll;
        delete removeParams['scrollTo'];
    } else {
        delete additionalParams['scrollTo'];
        removeParams['scrollTo'] = true;
    }
}

/* hide a element by id */
function hideElement(id, icon) {
  var pane;
  if(typeof(id) == 'object') {
    pane = id;
  }
  else {
    pane = document.getElementById(id);
  }
  if(!pane) {
    if(thruk_debug_js) { alert("ERROR: got no element for id in hideElement(): " + id); }
    return;
  }
  pane.style.display    = 'none';
  pane.style.visibility = 'hidden';

  var img = document.getElementById(icon);
  if(img && img.src) {
    img.src = img.src.replace(/icon_minimize\.gif/g, "icon_maximize.gif");
  }
}

/* show a element by id */
var close_elements = [];
function showElement(id, icon, bodyclose, bodycloseelement, bodyclosecallback) {
  var pane;
  if(typeof(id) == 'object') {
    pane = id;
  }
  else {
    pane = document.getElementById(id);
  }
  if(!pane) {
    if(thruk_debug_js) { alert("ERROR: got no element for id in showElement(): " + id); }
    return;
  }
  pane.style.display    = '';
  pane.style.visibility = 'visible';

  var img = document.getElementById(icon);
  if(img && img.src) {
    img.src = img.src.replace(/icon_maximize\.gif/g, "icon_minimize.gif");
  }

  if(bodyclose) {
    remove_close_element(id);
    window.setTimeout(function() {
        addEvent(document, 'click', close_and_remove_event);
        var found = false;
        jQuery.each(close_elements, function(key, value) {
            if(value[0] == id) {
                found = true;
            }
        });
        if(!found) {
            close_elements.push([id, icon, bodycloseelement, bodyclosecallback])
        }
    }, 50);
  }
}

/* remove element from close elements list */
function remove_close_element(id) {
    var new_elems = [];
    jQuery.each(close_elements, function(key, value) {
        if(value[0] != id) {
            new_elems.push(value);
        }
    });
    close_elements = new_elems;
    if(new_elems.length == 0) {
        removeEvent(document, 'click', close_and_remove_event);
    }
}

/* close and remove eventhandler */
function close_and_remove_event(evt) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    if(close_elements.length == 0) {
        return;
    }
    var x,y;
    if(evt) {
        evt = jQuery.event.fix(evt); // make pageX/Y available in IE
        x = evt.pageX;
        y = evt.pageY;

        // hilight click itself
        //hilight_area(x-5, y-5, x + 5, y + 5, 1000, 'blue');
    }
    var new_elems = [];
    jQuery.each(close_elements, function(key, value) {
        var obj    = document.getElementById(value[0]);
        if(value[2]) {
            obj = jQuery(value[2])[0];
        }
        var inside = false;
        if(x && y && obj) {
            var width  = jQuery(obj).outerWidth();
            var height = jQuery(obj).outerHeight();
            var offset = jQuery(obj).offset();

            var x1 = offset['left'] - 15;
            var x2 = offset['left'] + width  + 15;
            var y1 = offset['top']  - 15;
            var y2 = offset['top']  + height + 15;

            // check if we clicked inside or outside the object we have to close
            if( x >= x1 && x <= x2 && y >= y1 && y <= y2 ) {
                inside = true;
            }

            // hilight checked area
            //var color = inside ? 'green' : 'red';
            //hilight_area(x1, y1, x2, y2, 1000, color);
        }

        // make sure our event target is not a subelement of the panel to close
        if(!inside && evt) {
            inside = is_el_subelement(evt.target, obj);
        }

        if(evt && inside) {
            new_elems.push(value);
        } else {
            if(value[3]) {
                value[3]();
            }
            hideElement(value[0], value[1]);
        }
    });
    close_elements = new_elems;
    if(new_elems.length == 0) {
        removeEvent(document, 'click', close_and_remove_event);
    }
}

/* toggle a element by id and load content from remote */
function toggleElementRemote(id, part, bodyclose) {
    var elements = jQuery('#'+id);
    if(!elements[0]) {
        if(thruk_debug_js) { alert("ERROR: got no panel for id in toggleElementRemote(): " + id); }
        return false;
    }
    resetRefresh();
    var el = elements[0];
    /* fetched already, just toggle */
    if(el.innerHTML) {
        toggleElement(id, undefined, bodyclose);
        return;
    }
    /* add loading image and fetch content */
    var append = "";
    if(has_debug_options) {
        append += "&debug=1";
    }
    el.innerHTML = "<img src='"+url_prefix + 'themes/' + theme + '/images/loading-icon.gif'+"'>";
    showElement(id, undefined, bodyclose);
    jQuery('#'+id).load(url_prefix+'cgi-bin/parts.cgi?part='+part+append, {}, function(text, status, req) {
        showElement(id, undefined, bodyclose);
        resetRefresh();
    })
}

/* toggle a element by id */
function toggleElement(id, icon, bodyclose, bodycloseelement, bodyclosecallback) {
  var pane = document.getElementById(id);
  if(!pane) {
    if(thruk_debug_js) { alert("ERROR: got no panel for id in toggleElement(): " + id); }
    return false;
  }
  resetRefresh();
  if(pane.style.visibility == "hidden" || pane.style.display == 'none') {
    showElement(id, icon, bodyclose, bodycloseelement, bodyclosecallback);
    return true;
  }
  else {
    hideElement(id, icon);
    // if we hide something, check if we have to close others too
    // but only if the element to close is not a subset of an existing to_close_element
    var inside = false;
    jQuery.each(close_elements, function(key, value) {
        var obj    = document.getElementById(value[0]);
        if(value[2]) {
            obj = jQuery(value[2])[0];
        }
        inside = is_el_subelement(pane, obj);
        if(inside) {
            return false; // break jQuery.each
        }
    });
    if(!inside) {
        try {
          close_and_remove_event();
        } catch(err) { debug(err) }
    }
    return false;
  }
}

/* return true if obj A is a subelement from obj B */
function is_el_subelement(obj_a, obj_b) {
    if(obj_a == obj_b) {
        return true;
    }
    while(obj_a.parentNode != undefined) {
        obj_a = obj_a.parentNode;
        if(obj_a == obj_b) {
            return true;
        }
    }
    return false;
}

/* save settings in a cookie */
function prefSubmit(url, current_theme) {
  var sel         = document.getElementById('pref_theme')
  if(current_theme != sel.value) {
    additionalParams['theme']      = '';
    additionalParams['reload_nav'] = 1;
    cookieSave('thruk_theme', sel.value);
    reloadPage();
  }
}

/* save settings in a cookie */
function prefSubmitSound(url, value) {
  cookieSave('thruk_sounds', value);
  reloadPage();
}

/* save something in a cookie */
function cookieSave(name, value, expires, domain) {
  var now       = new Date();
  var expirestr = '';

  // let the cookie expire in 10 years by default
  if(expires == undefined) { expires = 10*365*86400; }

  if(expires > 0) {
    expires   = new Date(now.getTime() + (expires*1000));
    expirestr = " expires=" + expires.toGMTString() + ";";
  }

  var cookieStr = name+"="+value+"; path="+cookie_path+";"+expirestr;

  if(domain) {
    cookieStr += ";domain="+domain;
  }

  document.cookie = cookieStr;
}

/* remove existing cookie */
function cookieRemove(name, path) {
    if(path == undefined) {
        path = cookie_path;
    }
    document.cookie = name+"=del; path="+path+";expires=Thu, 01 Jan 1970 00:00:01 GMT";
}

/* return cookie value */
var cookies;
function readCookie(name,c,C,i){
    if(cookies){ return cookies[name]; }

    c = document.cookie.split('; ');
    cookies = {};

    for(i=c.length-1; i>=0; i--){
       C = c[i].split('=');
       cookies[C[0]] = C[1];
    }

    return cookies[name];
}

/* page refresh rate */
function setRefreshRate(rate) {
  if(rate >= 0 && rate < 20) {
      // check lastUserInteraction date to not refresh while user is interacting with the page
      if(lastUserInteraction > ((new Date).getTime() - 20000)) {
          lastUserInteraction = undefined;
          rate = 20;
      }
  }
  curRefreshVal = rate;
  var obj = document.getElementById('refresh_rate');
  if(refreshPage == 0) {
    if(obj) {
        obj.innerHTML = "This page will not refresh automatically <input type='button' value='refresh now' onClick='reloadPage()'>";
    }
  }
  else {
    if(obj) {
        obj.innerHTML = "Update in "+rate+" seconds <input type='button' value='stop' onClick='stopRefresh()'>";
    }
    if(rate == 0) {
      var has_auto_reload_fn = false;
      try {
        if(auto_reload_fn && typeof(auto_reload_fn) == 'function') {
            has_auto_reload_fn = true;
        }
      } catch(err) {}
      if(has_auto_reload_fn) {
        auto_reload_fn(function(state) {
            if(state) {
                var d = new Date();
                var new_date = d.strftime(datetime_format_long);
                jQuery('#infoboxdate').html(new_date);
            } else {
                jQuery('#infoboxdate').html('<span class="fail_message">refresh failed<\/span>');
            }
        });
        resetRefresh();
      } else {
        reloadPage();
      }
    }
    if(rate > 0) {
      newRate = rate - 1;
      window.clearTimeout(refreshTimer);
      refreshTimer = window.setTimeout("setRefreshRate(newRate)", 1000);
    }
  }
}

/* reset refresh interval */
function resetRefresh() {
  window.clearTimeout(refreshTimer);
  if( typeof refresh_rate == "number" ) {
    setRefreshRate(refresh_rate);
  } else {
    stopRefresh();
  }
}

/* stops the reload interval */
function stopRefresh() {
  refreshPage = 0;
  setRefreshRate(0);
}

/* is this an array? */
function is_array(o) {
    return typeof(o) == 'object' && (o instanceof Array);
}

/* return url variables as hash */
function toQueryParams(str) {
    var vars = {};
    if(str == undefined) {
        var i = window.location.href.indexOf('?');
        if(i == -1) {
            return vars;
        }
        str = window.location.href.slice(i + 1);
    }
    if (str == "") { return vars; };
    str = str.replace(/#.*$/g, '');
    str = str.split('&');
    for (var i = 0; i < str.length; ++i) {
        var p = [str[i]];
        // cannot use split('=', 2) here since it ignores everything after the limit
        var b = str[i].indexOf("=");
        if(b != -1) {
            p = [str[i].substr(0, b), str[i].substr(b+1)];
        }
        var val;
        if (p.length == 1) {
            val = undefined;
        } else {
            val = decodeURIComponent(p[1].replace(/\+/g, " "));
        }
        if(vars[p[0]] != undefined) {
            if(is_array(vars[p[0]])) {
                vars[p[0]].push(val);
            } else {
                var tmp =  vars[p[0]];
                vars[p[0]] = new Array();
                vars[p[0]].push(tmp);
                vars[p[0]].push(val);
            }
        } else {
            vars[p[0]] = val;
        }
    }
    return vars;
}

/* create query string from object */
function toQueryString(obj) {
    var str = '';
    for(var key in obj) {
        var value = obj[key];
        if(typeof(value) == 'object') {
            for(var key2 in value) {
                var value2 = value[key2];
                str = str + key + '=' + encodeURIComponent(value2) + '&';
            };
        } else if (value == undefined) {
            str = str + key + '&';
        }
        else {
            str = str + key + '=' + encodeURIComponent(value) + '&';
        }
    };
    // remove last &
    str = str.substring(0, str.length-1);
    return str;
}

function getCurrentUrl(addTimeAndScroll) {
    var origHash = window.location.hash;
    var newUrl   = window.location.href;
    newUrl       = newUrl.replace(/#.*$/g, '');

    if(addTimeAndScroll == undefined) { addTimeAndScroll = true; }

    // save scroll state
    saveScroll();

    var urlArgs  = toQueryParams();
    for(var key in additionalParams) {
        urlArgs[key] = additionalParams[key];
    }

    for(var key in removeParams) {
        delete urlArgs[key];
    }

    if(urlArgs['highlight'] != undefined) {
        delete urlArgs['highlight'];
    }

    // make url uniq, otherwise we would to do a reload
    // which reloads all images / css / js too
    if(addTimeAndScroll) {
        urlArgs['_'] = (new Date()).getTime();
    } else {
        delete urlArgs["scrollTo"];
    }

    var newParams = toQueryString(urlArgs);

    newUrl = newUrl.replace(/\?.*$/g, '');
    if(newParams != '') {
        newUrl = newUrl + '?' + newParams;
    }

    if(origHash != '#' && origHash != '') {
        newUrl = newUrl + origHash;
    }
    return(newUrl);
}

function uriWith(uri, params, removeParams) {
    uri  = uri || window.location.href;
    var urlArgs  = toQueryParams(uri);

    for(var key in params) {
        urlArgs[key] = params[key];
    }

    if(removeParams) {
        for(var key in removeParams) {
            delete urlArgs[key];
        }
    }

    var newParams = toQueryString(urlArgs);

    var newUrl = uri.replace(/\?.*$/g, '');
    if(newParams != '') {
        newUrl = newUrl + '?' + newParams;
    }

    return(newUrl);
}

/* update the url by using additionalParams */
function updateUrl() {
    var newUrl = getCurrentUrl(false);
    try {
        history.replaceState({}, "", newUrl);
    } catch(err) { debug(err) }
}

/* reloads the current page and adds some parameter from a hash */
function reloadPage() {
    window.clearTimeout(refreshTimer);
    var obj = document.getElementById('refresh_rate');
    if(obj) {
        obj.innerHTML = "<span id='refresh_rate'>page will be refreshed...</span>";
    }

    var newUrl = getCurrentUrl();

    if(fav_counter) {
        updateFaviconCounter('Zz', '#F7DA64', true, "10px Bold Tahoma", "#BA2610");
    }

    /* set reload mark in side frame */
    if(window.parent.frames && top.frames && top.frames['side']) {
        try {
            top.frames['side'].is_reloading = newUrl;
        }
        catch(err) {
            debug(err);
        }
    }

    /*
     * reload new url and replace history
     * otherwise history will contain every
     * single reload
     * and give the browser some time to update refresh buttons
     * and icons
     */
    window.setTimeout("window_location_replace('"+newUrl+"')", 100);
}

/* wrapper for window.location which results in
 * Uncaught TypeError: Illegal invocation
 * otherwise. (At least in chrome)
 */
function window_location_replace(url) {
    window.location.replace(url);
}

function get_site_panel_backend_button(id, styles, onclick, section) {
    if(!initial_backends[id] || !initial_backends[id]['cls']) { return(""); }
    var cls = initial_backends[id]['cls'];
    var title = initial_backends[id]['last_error'];
    if(cls != "DIS") {
        if(initial_backends[id]['last_online'] && initial_backends[id]['last_online'] > 30) {
            title += "\nLast Online: "+duration(initial_backends[id]['last_online'])+" ago";
            if(cls == "UP" && initial_backends[id]['last_error'] != "OK") {
                cls = "WARN";
            }
        }
    }
    var btn = '<input type="button"';
    btn += " id='button_"+id+"'";
    btn += ' class="button_peer'+cls+' backend_'+id+' section_'+section+'"';
    btn += ' value="'+initial_backends[id]['name']+'"';
    btn += ' title="'+escapeHTML(title).replace(/"/, "'")+'"';
    if(initial_backends[id]['disabled'] == 5) {
        btn += ' disabled'
    } else {
        btn += ' onClick="'+onclick+'">';
    }

    return("<div class='backend' style='"+styles+"'>"+btn+"<\/div>");
}

/* create sites header */
function dw(txt) {document.write(txt);}

/* create sites popup */
function create_site_panel_popup() {
    var panel = ''
        +'<div class="shadow"><div class="shadowcontent">'
        +'<table class="site_panel" cellspacing=0 cellpadding=0 width="100%">'
        +'  <tr>'
        +'    <th align="center">'
        +'      <table border=0 cellpadding=0 cellspacing=0 width="100%" style="padding-bottom: 10px;">'
        +'        <tr>';
    if(backend_chooser != 'switch') {
        panel += '      <td width="20"></td>';
        panel += '      <td width="70"></td>';
    }
    panel += '          <td style="padding-right: 20px;">Choose your sites</td>';
    if(backend_chooser != 'switch') {
        panel += '      <td align="right" width="70" class="clickable" onclick="toggleAllSections(true);">enable all</td>';
        panel += '      <td align="left" width="20"><input type="checkbox" id="all_backends" value="" name="all_backends" onclick="toggleAllSections();"></td>';
    }
    panel += '        </tr>';
    panel += '      </table>';
    panel += '    </th>';
    panel += '  </tr>';
    panel += '</table>';

    if(show_sitepanel == "panel") {
        panel += create_site_panel_popup_panel();
    }
    else if(show_sitepanel == "collapsed") {
        panel += create_site_panel_popup_collapsed();
    }

    panel += '<\/div><\/div>';
    document.getElementById('site_panel').innerHTML = panel;
}

function create_site_panel_popup_panel() {
    panel  = '<div class="site_panel_sections" style="overflow: auto;">';
    panel += '<table class="site_panel" cellspacing=0 cellpadding=0 width="100%">';
    panel += '  <tr>';
    if(sites["sub"] && keys(sites["sub"]).length > 1) {
        jQuery(keys(sites["sub"]).sort()).each(function(i, subsection) {
            if(sites["sub"][subsection].total == 0) { return; }
            panel += '<th class="site_panel '+(i==0 ? '' : "notfirst")+'">';
            panel += '  <a href="#" class="sites_subsection" onclick="toggleSection([\''+subsection+'\']); return false;" title="'+subsection+'">'+subsection+'</a>';
            panel += '</th>';
        });
    }
    panel += '  </tr>';
    panel += '  <tr>';
    jQuery(keys(sites["sub"]).sort()).each(function(i, subsection) {
        if(sites["sub"][subsection].total == 0) { return; }
        panel += '<td valign="top" class="site_panel '+(i==0 ? "" : "notfirst")+'" align="center">';
        panel += '<table cellpadding=0 cellspacing=0 border=0><tr class="subpeers_'+subsection+'">';
        panel += '<td valign="top">';
        var count = 0;
        jQuery(_site_panel_flat_peers(sites["sub"][subsection])).each(function(i, pd) {
            panel += get_site_panel_backend_button(pd, "clear: both;", "toggleBackend('"+pd+"')", toClsName(subsection));
            count++;
            if(count > 15) { count = 0; panel += '</td><td valign="top">'; }
        });
        panel += '</td>';
        panel += '</tr></table>';
        panel += '</td>';
    });
    panel += '  </tr>';
    panel += '</table>';
    panel += '<\/div>';
    return(panel);
}

function _site_panel_flat_peers(section) {
    var peers = [];
    if(section["sub"]) {
        jQuery(keys(section["sub"]).sort()).each(function(i, subsection) {
            peers = peers.concat(_site_panel_flat_peers(section["sub"][subsection]));
        });
    }
    if(section["peers"]) {
        jQuery(section["peers"]).each(function(i, p) {
            peers.push(p);
        });
    }
    return(peers);
}

function toClsName(name) {
    name = name.replace(/[^a-zA-Z0-9]+/g, '-');
    return(name);
}

function toClsNameList(list, join_char) {
    var out = [];
    if(join_char == undefined) { join_char = '_'; }
    for(var x = 0; x < list.length; x++) {
        out.push(toClsName(list[x]));
    }
    return(out.join(join_char));
}

function create_site_panel_popup_collapsed() {
    panel  = '<div class="site_panel_sections" style="overflow: auto;">';
    panel += '<table class="site_panel" cellspacing=0 cellpadding=0 width="100%">';
    jQuery(keys(sites.sub).sort()).each(function(i, sectionname) {
        if(i > 0) {
            panel += '  <tr>';
            panel += '    <td><hr class="sites_collapsed"></td>';
            panel += '  </tr>';
        }
        panel += '<tr>';
        panel += ' <th align="left">';
        panel += '   <a href="#" onclick="toggleSection([\''+sectionname+'\']); return false;" title="'+sectionname+'" class="sites_subsection">'+sectionname+'</a>';
        panel += '  </th>';
        panel += '</tr>';
        // show first two levels of sections
        panel += add_site_panel_popup_collapsed_section(sites["sub"][sectionname], [sectionname]);
        // including peers
        if(sites["sub"][sectionname]["peers"]) {
            panel += '  <tr class="subpeer subpeers_'+(toClsName(sectionname))+' sublvl_1">';
            panel += '    <th align="left" style="padding-left: 10px;">';
            jQuery(sites["sub"][sectionname]["peers"]).each(function(i, pd) {
                panel += get_site_panel_backend_button(pd, "", "toggleBackend('"+pd+"')", toClsName(sectionname));
            });
            panel += '    </th>';
            panel += '  </tr>';
        }
    });

    // add top level peers
    if(sites["peers"]) {
        panel += '  <tr class="subpeer subpeers_top">';
        panel += '    <th align="left">';
        panel += '    <hr class="sites_collapsed">';
        jQuery(sites["peers"]).each(function(i, pd) {
            panel += get_site_panel_backend_button(pd, "", "toggleBackend('"+pd+"')", "top");
        });
        panel += '    </th>';
        panel += '  </tr>';
    }

    // add all other peers
    jQuery(keys(sites.sub).sort()).each(function(i, sectionname) {
        panel += add_site_panel_popup_collapsed_peers(sites["sub"][sectionname], [sectionname]);
    });

    panel += '</table>';
    panel += '<\/div>';
    return(panel);
}

function add_site_panel_popup_collapsed_section(section, prefix) {
    var lvl = prefix.length;
    panel = "";
    var prefixCls = toClsNameList(prefix);
    if(section["sub"]) {
        panel += '  <tr style="'+(lvl > 1 ? 'display: none;' : '')+'" class="subsection subsection_'+prefixCls+' sublvl_'+lvl+'">';
        panel += '    <th align="left" style="padding-left: '+(lvl*10)+'px;">';
        jQuery(keys(section["sub"]).sort()).each(function(i, sectionname) {
            var subsection = section["sub"][sectionname];
            var new_prefix = prefix.concat(sectionname);
            var cls = 'button_peerDIS';
            if(subsection.total == subsection.up) { cls = 'button_peerUP'; }
            if(subsection.total == subsection.down) { cls = 'button_peerDOWN'; }
            if(subsection.total == subsection.disabled) { cls = 'button_peerDIS'; }
            if(subsection.up  > 0 && subsection.down > 0) { cls = 'button_peerWARN'; }
            if(subsection.up  > 0 && subsection.disabled > 0 && subsection.down == 0) { cls = 'button_peerUPDIS'; }
            if(subsection.up == 0 && subsection.disabled > 0 && subsection.down > 0) { cls = 'button_peerDOWNDIS'; }
            panel += "<input type='button' class='"+cls+" btn_sites btn_sites_"+prefixCls+"_"+toClsName(sectionname)+"' value='"+sectionname+"' onClick='toggleSubSectionVisibility("+JSON.stringify(new_prefix)+")'>";
            panel += "<span class='btn_sitesplus'>+</span>";
        });
        panel += '    </th>';
        panel += '  </tr>';

        jQuery(keys(section["sub"]).sort()).each(function(i, sectionname) {
            var subsection = section["sub"][sectionname];
            var new_prefix = prefix.concat(sectionname);
            panel += add_site_panel_popup_collapsed_section(subsection, new_prefix);
        });
    }

    return(panel);
}

function add_site_panel_popup_collapsed_peers(section, prefix) {
    var lvl = prefix.length;
    panel = "";
    if(section["peers"]) {
        var prefixCls = toClsNameList(prefix);
        panel += '  <tr class="subpeer subpeers_'+prefixCls+'" style="display: none;">';
        panel += '    <th align="left">';
        panel += '    <hr class="sites_collapsed last">';

        panel += '    <table><tr><td>';
        panel += "      <input type='checkbox' onclick='toggleSection("+JSON.stringify(prefix)+");' class='clickable section_check_box_"+prefixCls+"'>";
        panel += '    </td><td style="vertical-align: middle;">';
        panel += "      <a href='#' onclick='toggleSection("+JSON.stringify(prefix)+"); return false;'><b>";
        panel += prefix.join(' -&gt; ');
        panel += '      </b></a>:';
        panel += '    </td></tr></table>';

        jQuery(section["peers"]).each(function(i, pd) {
            panel += get_site_panel_backend_button(pd, "", "toggleBackend('"+pd+"')", prefixCls);
        });
        panel += '    </th>';
        panel += '  </tr>';
    }
    if(section["sub"]) {
        jQuery(keys(section["sub"]).sort()).each(function(i, sectionname) {
            var subsection = section["sub"][sectionname];
            var new_prefix = prefix.concat(sectionname);
            panel += add_site_panel_popup_collapsed_peers(subsection, new_prefix);
        });
    }
    return(panel);
}

/* toggle site panel */
/* $%&$&% site panel position depends on the button height */
function toggleSitePanel() {
    if(!document.getElementById('site_panel').innerHTML) {
        create_site_panel_popup();
    }
    var enabled = toggleElement('site_panel', undefined, true, 'DIV#site_panel DIV.shadowcontent', toggleSitePanel);
    var divs = jQuery('DIV.backend');
    var panel = document.getElementById('site_panel');
    panel.style.top = (divs[0].offsetHeight + 11) + 'px';

    /* make sure site panel does not overlap screen */
    var div = jQuery('DIV.site_panel_sections')[0];
    if(enabled == true) {
        var table = jQuery('TABLE.top_nav')[0];
        var newWidth = table.offsetWidth - 10;
        if(newWidth < div.offsetWidth) {
            div.style.width = newWidth + 'px';
        }
    } else {
        // reset styles till next open
        div.style.width = '';
        // immediately reload if there were changes
        if(additionalParams['reload_nav']) {
            window.clearTimeout(backendSelTimer);
            removeParams['backends'] = true;
            backendSelTimer  = window.setTimeout('reloadPage()', 50);
        }
    }

    updateSitePanelCheckBox();
}

/* toggle querys for this backend */
function toggleBackend(backend, state, skip_update) {
  resetRefresh();
  var button        = document.getElementById('button_' + backend);
  if(state == undefined) { state = -1; }

  if(backend_chooser == 'switch') {
    jQuery('INPUT.button_peerUP').removeClass('button_peerUP').addClass('button_peerDIS');
    jQuery(button).removeClass('button_peerDIS').addClass('button_peerUP');
    cookieSave('thruk_conf', backend);
    removeParams['backends'] = true;
    reloadPage();
    return;
  }

  if(current_backend_states == undefined) {
    current_backend_states = {};
    for(var key in initial_backends) { current_backend_states[key] = initial_backends[key]['state']; }
  }

  initial_state = initial_backends[backend]['state'];
  var newClass  = undefined;
  if((jQuery(button).hasClass("button_peerDIS") && state == -1) || state == 1) {
    if(initial_state == 1) {
      newClass = "button_peerDOWN";
    }
    else {
      newClass = "button_peerUP";
    }
    current_backend_states[backend] = 0;
  } else if(jQuery(button).hasClass("button_peerHID") && state != 1) {
    newClass = "button_peerUP";
    current_backend_states[backend] = 0;
    delete additionalParams['backend'];
  } else {
    newClass = "button_peerDIS";
    current_backend_states[backend] = 2;
  }

  /* remove all and set new class */
  jQuery(button).removeClass("button_peerDIS button_peerHID button_peerUP button_peerDOWN").addClass(newClass);

  additionalParams['reload_nav'] = 1;
  /* save current selected backends in session cookie */
  cookieSave('thruk_backends', toQueryString(current_backend_states));
  window.clearTimeout(backendSelTimer);
  // remove &backends=... from url, they would overwrite cookie settings
  removeParams['backends'] = true;

  var delay = 2500;
  if(show_sitepanel == 'panel')     { delay =  3500; }
  if(show_sitepanel == 'collapsed') { delay = 10000; }
  backendSelTimer  = window.setTimeout('reloadPage()', delay);

  if(skip_update == undefined || !skip_update) {
    updateSitePanelCheckBox();
  }
  return;
}

/* toggle subsection */
function toggleSubSectionVisibility(subsection) {
    // hide everything
    jQuery('TR.subpeer, TR.subsection').css('display', 'none');
    jQuery('TR.subsection INPUT').removeClass('button_peer_selected');

    // show parents sections
    var subsectionCls = toClsNameList(subsection);
    var cls = '';
    for(var x = 0; x < subsection.length; x++) {
        if(cls != "") { cls = cls+'_'; }
        cls = cls+toClsName(subsection[x]);
        // show section itself
        jQuery('TR.subsection_'+cls).css('display', '');
        // but hide all subsections
        jQuery('TR.subsection_'+cls+' INPUT').css('display', 'none');
        // except the one we want to see
        jQuery('INPUT.btn_sites_'+cls).css('display', '').addClass('button_peer_selected');
    }

    // show section itself
    jQuery('TR.subsection_'+subsectionCls).css('display', '');
    jQuery('TR.subsection_'+subsectionCls+' INPUT').css('display', '');

    // show peer for this subsection
    jQuery('TR.subpeers_'+subsectionCls).css('display', '');
    jQuery('TR.subpeers_'+subsectionCls+' INPUT').css('display', '');

    // always show top sections
    jQuery('TR.sublvl_1').css('display', '');
    jQuery('TR.sublvl_1 INPUT').css('display', '');
}

/* toggle all backends for this section */
function toggleSection(sections) {
    var first_state = undefined;
    var section = toClsNameList(sections);
    var regex   = new RegExp('section_'+section+'(_|\\\s|$)');
    jQuery('TABLE.site_panel INPUT[type=button]').each(function(i, b) {
        var id = b.id.replace(/^button_/, '');
        if(!id) { return; }
        if(!b.className.match(regex)) { return; }
        if(first_state == undefined) {
            if(jQuery(b).hasClass("button_peerUP") || jQuery(b).hasClass("button_peerDOWN")) {
                first_state = 0;
            } else {
                first_state = 1;
            }
        }
        toggleBackend(id, first_state, true);
    });

    updateSitePanelCheckBox();
}

/* toggle all backends for all sections */
function toggleAllSections(reverse) {
    var state = 0;
    if(jQuery('#all_backends').prop('checked')) {
        state = 1;
    }
    if(reverse != undefined) {
        if(state == 0) { state = 1; } else { state = 0; }
    }
    jQuery('TABLE.site_panel DIV.backend INPUT').each(function(i, b) {
        if(b.id.match(/^button_/)) {
            var id = b.id.replace(/^button_/, '');
            toggleBackend(id, state, true);
        }
    });

    updateSitePanelCheckBox();
}

/* update all site panel checkboxes and section button */
function updateSitePanelCheckBox() {
    /* count totals */
    count_site_section_totals(sites, []);

    /* enable all button */
    if(sites['disabled'] > 0) {
        jQuery('#all_backends').prop('checked', false);
    } else {
        jQuery('#all_backends').prop('checked', true);
    }
}

/* count totals for a section */
function count_site_section_totals(section, prefix) {
    section.total    = 0;
    section.disabled = 0;
    section.down     = 0;
    section.up       = 0;
    if(section["sub"]) {
        jQuery(keys(section["sub"]).sort()).each(function(i, sectionname) {
            var subsection = section["sub"][sectionname];
            var new_prefix = prefix.concat(sectionname);
            count_site_section_totals(subsection, new_prefix);
            section.total    += subsection.total;
            section.disabled += subsection.disabled;
            section.down     += subsection.down;
            section.up       += subsection.up;
        });
    }

    if(section["peers"]) {
        jQuery(section["peers"]).each(function(i, pd) {
            var btn = document.getElementById("button_"+pd);
            if(!btn) { return; }
            section.total++;
            if(jQuery(btn).hasClass('button_peerDIS') || jQuery(btn).hasClass('button_peerHID')) {
                section.disabled++;
            }
            else if(jQuery(btn).hasClass('button_peerUP')) {
                section.up++;
            }
            else if(jQuery(btn).hasClass('button_peerDOWN')) {
                section.down++;
            }
        });
    }

    if(prefix.length == 0) { return; }

    /* set section button */
    var prefixCls = toClsNameList(prefix);
    var newBtnClass = "";
    if(section.disabled == section.total) {
        newBtnClass = "button_peerDIS";
    }
    else if(section.up == section.total) {
        newBtnClass = "button_peerUP";
    }
    else if(section.down == section.total) {
        newBtnClass = "button_peerDOWN";
    }
    else if(section.down > 0 && section.up > 0) {
        newBtnClass = "button_peerWARN";
    }
    else if(section.up > 0 && section.disabled > 0 && section.down == 0) {
        newBtnClass = "button_peerUPDIS";
    }
    else if(section.disabled > 0 && section.down > 0 && section.up == 0) {
        newBtnClass = "button_peerDOWNDIS";
    }
    jQuery('.btn_sites_' + prefixCls)
            .removeClass("button_peerDIS")
            .removeClass("button_peerDOWN")
            .removeClass("button_peerUP")
            .removeClass("button_peerWARN")
            .removeClass("button_peerUPDIS")
            .removeClass("button_peerDOWNDIS")
            .addClass(newBtnClass);

    /* set section checkbox */
    if(section.disabled > 0) {
        jQuery('.section_check_box_'+prefixCls).prop('checked', false);
    } else {
        jQuery('.section_check_box_'+prefixCls).prop('checked', true);
    }
}

function duration(seconds) {
    if(seconds < 300) {
        return(seconds+" seconds");
    }
    if(seconds < 7200) {
        return(Math.floor(seconds/60)+" minutes");
    }
    if(seconds < 86400*2) {
        return(Math.floor(seconds/3600)+" hours");
    }
    return(Math.floor(seconds/86400)+" days");
}

/* toggle checkbox by id */
function toggleCheckBox(id) {
  var box = document.getElementById(id);
  if(box.checked) {
    box.checked = false;
  } else {
    box.checked = true;
  }
}

/* toggle disabled status */
function toggleDisabled(id) {
  var thing = document.getElementById(id);
  if(thruk_debug_js && thing == undefined) { alert("ERROR: no element in toggleDisabled() for: " + id ); }
  if(thing.disabled) {
    thing.disabled = false;
  } else {
    thing.disabled = true;
  }
}

/* unselect current text seletion */
function unselectCurrentSelection(obj) {
    if (document.selection && document.selection.empty)
    {
        document.selection.empty();
    }
    else
    {
        window.getSelection().removeAllRanges();
    }
    return true;
}

/* return selected text */
function getTextSelection() {
    var t = '';
    if(window.getSelection) {
        t = window.getSelection();
    } else if(document.getSelection) {
        t = document.getSelection();
    } else if(document.selection) {
        t = document.selection.createRange().text;
    }
    return ''+t;
}

/* returns true if the shift key is pressed for that event */
var no_more_events = 0;
function is_shift_pressed(evt) {

  if(no_more_events) {
    return false;
  }

  if(evt && evt.shiftKey) {
    return true;
  }

  try {
    if(event && event.shiftKey) {
      return true;
    }
  }
  catch(err) {
    // errors wont matter here
  }

  return false;
}

/* moves element from one select to another */
function data_select_move(from, to, skip_sort) {
    var from_sel = document.getElementsByName(from);
    if(!from_sel || from_sel.length == 0) {
        if(thruk_debug_js) { alert("ERROR: no element in data_select_move() for: " + from ); }
    }
    var to_sel = document.getElementsByName(to);
    if(!to_sel || to_sel.length == 0) {
        if(thruk_debug_js) { alert("ERROR: no element in data_select_move() for: " + to ); }
    }

    from_sel = from_sel[0];
    to_sel   = to_sel[0];

    if(from_sel.selectedIndex < 0) {
        return;
    }

    var elements = new Array();
    for(var nr = 0; nr < from_sel.length; nr++) {
        if(from_sel.options[nr].selected == true) {
            elements.push(nr);
            var option = from_sel.options[nr];
            if(originalOptions[to] != undefined) {
                originalOptions[to].push(new Option(option.text, option.value));
            }
            if(originalOptions[from] != undefined) {
                jQuery.each(originalOptions[from], function(i, o) {
                    if(o.value == option.value) {
                        originalOptions[from].splice(i, 1);
                        return false;
                    }
                    return true;
                });
            }
        }
    }

    // reverse elements so the later remove doesn't disorder the select
    elements.reverse();

    var elements_to_add = new Array();
    for(var x = 0; x < elements.length; x++) {
        var elem       = from_sel.options[elements[x]];
        var elOptNew   = document.createElement('option');
        elOptNew.text  = elem.text;
        elOptNew.value = elem.value;
        from_sel.remove(elements[x]);
        elements_to_add.push(elOptNew);
    }

    elements_to_add.reverse();
    for(var x = 0; x < elements_to_add.length; x++) {
        var elOptNew = elements_to_add[x];
        try {
          to_sel.add(elOptNew, null); // standards compliant; doesn't work in IE
        }
        catch(ex) {
          to_sel.add(elOptNew); // IE only
        }
    }

    /* sort elements of to field */
    if(!skip_sort) {
        sortlist(to_sel.id);
    }
}

/* filter select field option */
var originalOptions = {};
function data_filter_select(id, filter) {
    var select  = document.getElementById(id);
    var pattern = get_trimmed_pattern(filter);

    if(!select) {
        if(thruk_debug_js) { alert("ERROR: no select in data_filter_select() for: " + id ); }
    }

    var options = select.options;
    /* create backup of original list */
    if(originalOptions[id] == undefined) {
        reset_original_options(id);
    } else {
        options = originalOptions[id];
    }

    /* filter our options */
    var newOptions = [];
    jQuery.each(options, function(i, option) {
        var found = 0;
        jQuery.each(pattern, function(i, sub_pattern) {
            var index = option.text.toLowerCase().indexOf(sub_pattern.toLowerCase());
            if(index != -1) {
                found++;
            }
        });
        /* all pattern found */
        if(found == pattern.length) {
            newOptions.push(option);
        }
    });
    // don't set uniq flag here, otherwise non-uniq lists will be uniq after init
    set_select_options(id, newOptions, false);
}

/* resets originalOptions hash for given id */
function reset_original_options(id) {
    var select  = document.getElementById(id);
    originalOptions[id] = [];
    jQuery.each(select.options, function(i, option) {
        originalOptions[id].push(new Option(option.text, option.value));
    });
}

/* set options for a select */
function set_select_options(id, options, uniq) {
    var select  = document.getElementById(id);
    var uniqs   = {};
    if(select == undefined || select.options == undefined) {
       if(thruk_debug_js) { alert("ERROR: no select found in set_select_options: " + id ); }
       return;
    }
    select.options.length = 0;
    jQuery.each(options, function(i, o) {
        if(!uniq || uniqs[o.text] == undefined) {
            select.options[select.options.length] = o;
            uniqs[o.text] = true;
        }
    });
}

/* select all options for given select form field */
function select_all_options(select_id) {
    // add selected nodes
    jQuery('#'+select_id+' OPTION').prop('selected',true);
}

/* return array of trimmed pattern */
function get_trimmed_pattern(pattern) {
    var trimmed_pattern = new Array();
    jQuery.each(pattern.split(" "), function(index, sub_pattern) {
        sub_pattern = sub_pattern.replace(/\s+$/g, "");
        sub_pattern = sub_pattern.replace(/^\s+/g, "");
        if(sub_pattern != '') {
            trimmed_pattern.push(sub_pattern);
        }
    });
    return trimmed_pattern;
}


/* return keys as array */
function keys(obj) {
    var k = [];
    for(var key in obj) {
        k.push(key);
    }
    return k;
}

/* sort select by value */
function sortlist(id) {
    var selectOptions = jQuery("#"+id+" option");
    selectOptions.sort(function(a, b) {
        if      (a.text > b.text) { return 1;  }
        else if (a.text < b.text) { return -1; }
        else                      { return 0;  }
    });
    jQuery("#"+id).empty().append(selectOptions);
}

/* fetch all select fields and select all options when it is multiple select */
function multi_select_all(form) {
    elems = form.getElementsByTagName('select');
    for(var x = 0; x < elems.length; x++) {
        var sel = elems[x];
        if(sel.multiple == true) {
            for(var nr = 0; nr < sel.length; nr++) {
                sel.options[nr].selected = true;
            }
        }
    }
}

/* remove a bookmark */
function removeBookmark(nr) {
    var pan  = document.getElementById("bm" + nr);
    var panP = pan.parentNode;
    panP.removeChild(pan);
    delete bookmarks["bm" + nr];
}

/* check if element is not emty */
function checknonempty(id, name) {
    var elem = document.getElementById(id);
    if( elem.value == undefined || elem.value == "" ) {
        alert(name + " is a required field");
        return(false);
    }
    return(true);
}

/* hide all waiting icons */
var hide_activity_icons_timer;
function hide_activity_icons() {
    jQuery('img').each(function(i, el) {
        if(el.src.indexOf("/images/waiting.gif") > 0) {
            el.style.visibility = "hidden";
        }
    });
}

/* verify time */
var verification_errors = new Object();
function verify_time(id, duration_id) {
    window.clearTimeout(verifyTimer);
    verifyTimer = window.setTimeout(function() {
        verify_time_do(id, duration_id);
    }, 500);
}
function verify_time_do(id, duration_id) {
    var obj  = document.getElementById(id);
    var obj2 = document.getElementById(duration_id);
    var duration = "";
    if(obj2 && jQuery(obj2).is(":visible")) {
        duration = obj2.value;
    }

    jQuery.ajax({
        url: url_prefix + 'cgi-bin/status.cgi',
        type: 'POST',
        data: {
            verify:     'time',
            time:        obj.value,
            duration:    duration,
            duration_id: duration_id
        },
        success: function(data) {
            var next = jQuery(obj).next();
            if(next[0] && next[0].className == 'smallalert') {
                jQuery(next).remove();
            }
            if(data.verified == "false") {
                debug(data.error);
                verification_errors[id] = 1;
                obj.style.background = "#f8c4c4";
                jQuery("<span class='smallalert'>"+data.error+"</span>").insertAfter(obj);
            } else {
                obj.style.background = "";
                delete verification_errors[id];
            }
        }
    });
}

/* return unescaped html string */
function unescapeHTML(html) {
    return jQuery("<div />").html(html).text();
}

/* return escaped html string */
function escapeHTML(text) {
    return jQuery("<div>").text(text).html();
}

/* reset table row classes */
function reset_table_row_classes(table, c1, c2) {
    var x = 1;
    jQuery('TABLE#'+table+' TR').each(function(i, row) {
        if(jQuery(row).css('display') == 'none') {
            // skip hidden rows
            return true;
        }
        jQuery(row).removeClass(c1);
        jQuery(row).removeClass(c2);
        x++;
        var newclass = c2;
        if(x%2 == 0) {
            newclass = c1;
        }
        jQuery(row).addClass(newclass);
        jQuery(row).children().each(function(i, elem) {
            if(elem.tagName == 'TD') {
                if(jQuery(elem).hasClass(c1) || jQuery(elem).hasClass(c2)) {
                    jQuery(elem).removeClass(c1);
                    jQuery(elem).removeClass(c2);
                    jQuery(elem).addClass(newclass);
                }
            }
        });
    });
}

/* set icon src and refresh page */
function refresh_button(btn) {
    btn.src = url_prefix + 'themes/' + theme + '/images/waiting.gif';
    jQuery(btn).addClass('refreshing');
    window.setTimeout(function() {
        reloadPage();
    }, 100);
}

/* reverse a string */
function reverse(s){
    return s.split("").reverse().join("");
}

/* set selection in text input */
function setSelectionRange(input, selectionStart, selectionEnd) {
    if (input.setSelectionRange) {
        input.focus();
        input.setSelectionRange(selectionStart, selectionEnd);
    }
    else if (input.createTextRange) {
        var range = input.createTextRange();
        range.collapse(true);
        range.moveEnd('character', selectionEnd);
        range.moveStart('character', selectionStart);
        range.select();
    }
}

/* set cursor position in text input */
function setCaretToPos(input, pos) {
    setSelectionRange(input, pos, pos);
}

/* set cursor line in textarea */
function setCaretToLine(input, line) {

    setSelectionRange(input, pos, pos);
}

/* get cursor position in text input */
function getCaret(el) {
    if (el.selectionStart) {
        return el.selectionStart;
    } else if (document.selection) {
        el.focus();

        var r = document.selection.createRange();
        if (r == null) {
            return 0;
        }

        var re = el.createTextRange(),
            rc = re.duplicate();
        re.moveToBookmark(r.getBookmark());
        rc.setEndPoint('EndToStart', re);

        return rc.text.length;
    }
    return 0;
}

/* generic sort function */
var sort_by = function(field, reverse, primer) {

   var key = function (x) {return primer ? primer(x[field]) : x[field]};

   return function (a,b) {
       var A = key(a), B = key(b);
       return (A < B ? -1 : (A > B ? 1 : 0)) * [1,-1][+!!reverse];
   }
}

/* numeric comparison function */
function compareNumeric(a, b) {
   return a - b;
}

/* make right pane visible */
function cron_change_date(id) {
    // get selected value
    type_sel = document.getElementById(id);
    var nr = type_sel.id.match(/_(\d+)$/)[1];
    type     = type_sel.options[type_sel.selectedIndex].value;
    hideElement('div_send_month_'+nr);
    hideElement('div_send_monthday_'+nr);
    hideElement('div_send_week_'+nr);
    hideElement('div_send_day_'+nr);
    hideElement('div_send_cust_'+nr);
    showElement('div_send_'+type+'_'+nr);

    if(type == 'cust') {
        hideElement('hour_select_'+nr);
    } else {
        showElement('hour_select_'+nr);
    }
}

/* remove a row */
function delete_cron_row(el) {
    var row = el;
    /* find first table row */
    while(row.parentNode != undefined && row.tagName != 'TR') { row = row.parentNode; }
    row.parentNode.deleteRow(row.rowIndex);
    return false;
}

/* remove a row */
function add_cron_row(tbl_id) {
    var tbl            = document.getElementById(tbl_id);
    var tblBody        = tbl.tBodies[0];

    /* get first table row */
    var row = tblBody.rows[0];
    var newRow = row.cloneNode(true);

    /* get highest number */
    var new_nr = 1;
    jQuery.each(tblBody.rows, function(i, r) {
        if(r.id) {
            var nr = r.id.match(/_(\d+)$/)[1];
            if(nr >= new_nr) {
                new_nr = parseInt(nr) + 1;
            }
        }
    });

    /* replace ids / names */
    replace_ids_and_names(newRow, new_nr);
    var all = newRow.getElementsByTagName('*');
    for (var i = -1, l = all.length; ++i < l;) {
        var elem = all[i];
        replace_ids_and_names(elem, new_nr);
    }

    newRow.style.display = "";

    var lastRowNr      = tblBody.rows.length - 1;
    var currentLastRow = tblBody.rows[lastRowNr];
    tblBody.insertBefore(newRow, currentLastRow);
}

/* filter table content by search field */
var table_search_input_id, table_search_table_ids, table_search_timer;
var table_search_cb = {};
function table_search(input_id, table_ids, nodelay) {
    table_search_input_id  = input_id;
    table_search_table_ids = table_ids;
    clearTimeout(table_search_timer);
    if(nodelay != undefined) {
        do_table_search();
    } else {
        table_search_timer = window.setTimeout('do_table_search()', 300);
    }
}
/* do the search work */
function do_table_search() {
    var ids      = table_search_table_ids;
    var value    = jQuery('#'+table_search_input_id).val();
    if(value == undefined) {
        return;
    }
    value    = value.toLowerCase();
    set_hash(value, 2);
    jQuery.each(ids, function(nr, id) {
        var table = document.getElementById(id);
        var matches = table.className.match(/searchSubTable_([^\ ]*)/);
        if(matches && matches[1]) {
            jQuery(table).find("TABLE."+matches[1]).each(function(x, t) {
                do_table_search_table(id, t, value);
            });
        } else {
            do_table_search_table(id, table, value);
        }
    });
}

function do_table_search_table(id, table, value) {
    /* make tables fixed width to avoid flickering */
    if(table.offsetWidth) {
        table.width = table.offsetWidth;
    }
    var startWith = 1;
    if(jQuery(table).hasClass('header2')) {
        startWith = 2;
    }
    if(jQuery(table).hasClass('search_vertical')) {
        var totalFound = 0;
        jQuery.each(table.rows[0].cells, function(col_nr, ref_cell) {
            if(col_nr < startWith) {
                return;
            }
            var found = 0;
            jQuery.each(table.rows, function(nr, row) {
                var cell = row.cells[col_nr];
                try {
                    if(cell.innerHTML.toLowerCase().match(value)) {
                        found = 1;
                    }
                } catch(err) {
                    if(cell.innerHTML.toLowerCase().indexOf(value) != -1) {
                        found = 1;
                    }
                }
            });
            jQuery.each(table.rows, function(nr, row) {
                var cell = row.cells[col_nr];
                if(found == 0) {
                    jQuery(cell).addClass('filter_hidden');
                } else {
                    jQuery(cell).removeClass('filter_hidden');
                }
            });
            if(found > 0) {
                totalFound++;
            }
        });
        if(jQuery(table).hasClass('search_hide_empty')) {
            if(totalFound == 0) {
                jQuery(table).addClass('filter_hidden');
            } else {
                jQuery(table).removeClass('filter_hidden');
            }
        }
    } else {
        jQuery.each(table.rows, function(nr, row) {
            if(nr < startWith) {
                return;
            }
            if(jQuery(row).hasClass('table_search_skip')) {
                return;
            }
            var found = 0;
            jQuery.each(row.cells, function(nr, cell) {
                /* if regex matching fails, use normal matching */
                try {
                    if(cell.innerHTML.toLowerCase().match(value)) {
                        found = 1;
                    }
                } catch(err) {
                    if(cell.innerHTML.toLowerCase().indexOf(value) != -1) {
                        found = 1;
                    }
                }
            });
            if(found == 0) {
                jQuery(row).addClass('filter_hidden');
            } else {
                jQuery(row).removeClass('filter_hidden');
            }
        });
    }
    if(table_search_cb[id] != undefined) {
        try {
            table_search_cb[id]();
        } catch(err) {
            debug(err);
        }
    }
}

/* show bug report icon */
function showBugReport(id, text) {
    var link = document.getElementById('bug_report-btnEl');
    var raw  = text;
    var href="mailto:"+bug_email_rcpt+"?subject="+encodeURIComponent("Thruk JS Error Report")+"&body="+encodeURIComponent(text);
    if(link) {
        text = "Please describe what you did:\n\n\n\n\nMake sure the report does not contain confidential information.\n\n---------------\n" + text;
        link.href=href;
    }

    var obj = document.getElementById(id);
    try {
        /* for extjs */
        Ext.getCmp(id).show();
        Ext.getCmp(id).setHref(href);
        Ext.getCmp(id).el.dom.ondblclick    = function() { return showErrorTextPopup(raw) };
        Ext.getCmp(id).el.dom.oncontextmenu = function() { return showErrorTextPopup(raw) };
        Ext.getCmp(id).el.dom.style.zIndex = 1000;
    }
    catch(err) {
        /* for all other pages */
        if(obj) {
            obj.style.display    = '';
            obj.style.visibility = 'visible';
            obj.ondblclick       = function() { return showErrorTextPopup(raw) };
            obj.oncontextmenu    = function() { return showErrorTextPopup(raw) };
        }
    }
}

/* show popup with the current error text */
function showErrorTextPopup(text) {
    text      = "<pre style='text-align:left;'>"+escapeHTML(text)+"<\/pre>";
    var title = "Error Report";
    if(window.overlib != undefined) {
        try {
            var options = [text,CAPTION,title,WIDTH,900];
            options     = options.concat(info_popup_options);
            overlib.apply(this, options);
        }
        catch(e) {}
    }
    if (window.Ext != undefined) {
        Ext.Msg.alert(title, text);
    }
    return(false);
}

/* create error text for bug reports */
function getErrorText(details, error) {
    var text = "";
    text = text + "Version:    " + version_info+"\n";
    text = text + "Release:    " + released+"\n";
    text = text + "Url:        " + window.location.pathname + "?" + window.location.search + "\n";
    text = text + "Browser:    " + navigator.userAgent + "\n";
    text = text + "Backends:   ";
    var first = 1;
    for(var nr=0; nr<initial_backends.length; nr++) {
        if(!first) { text = text + '            '; }
        text = text + initial_backends[nr].state + ' / ' + initial_backends[nr].version + ' / ' + initial_backends[nr].data_src_version + "\n";
        first = 0;
    }
    text = text + details;
    text = text + "Error List:\n";
    for(var nr=0; nr<thruk_errors.length; nr++) {
        text = text + thruk_errors[nr]+"\n";
    }

    /* try to get a stacktrace */
    var stacktrace = "";
    text += "\n";
    text += "Full Stacktrace:\n";
    if(error && error.stack) {
        text = text + error.stack;
        stacktrace = stacktrace + error.stack;
    }
    try {
        var stack = [];
        var f = arguments.callee.caller;
        while (f) {
            if(f.name != 'thruk_onerror') {
                stack.push(f.name);
            }
            f = f.caller;
        }
        text = text + stack.join("\n");
        stacktrace = stacktrace + stack.join("\n");
    } catch(err) {}

    /* try to get source mapping */
    try {
        var file = error.fileName;
        var line = error.lineNumber;
        /* get filename / line from stack if possible */
        var stackExplode = stacktrace.split(/\n/);
        for(var nr=0; nr<stackExplode.length; nr++) {
            if(!stackExplode[nr].match(/eval/)) {
                var matches = stackExplode[nr].match(/(https?:.*?):(\d+):(\d+)/i);
                if(matches && matches[2]) {
                    file = matches[1];
                    line = Number(matches[2]);
                    nr = stackExplode.length + 1;
                }
            }
        }
        if(window.XMLHttpRequest && file && !file.match("eval")) {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", file);
            xhr.setRequestHeader("Content-Type", "text/plain;charset=UTF-8");
            xhr.send(null);
            var source = xhr.responseText.split(/\n/);
            text += "\n";
            text += "Source:\n";
            if(line > 2) { text += shortenSource(source[line-2]); }
            if(line > 1) { text += shortenSource(source[line-1]); }
            text += shortenSource(source[line]);
        }
    } catch(err) {}

    /* this only works in panorama view */
    /*
     *removed... doesn't help much and just fills the logfile
    try {
        if(TP.logHistory) {
            text += "\n";
            text += "Panorama Log:\n";
            var formatLogEntry = function(entry) {
                var date = Ext.Date.format(entry[0], "Y-m-d H:i:s.u");
                return('['+date+'] '+entry[1]+"\n");
            }
            for(var i=TP.logHistory.length-1; i > 0; i--) {
                text += formatLogEntry(TP.logHistory[i]);
            }
        }
    } catch(err) {}
    */
    text += "\n";
    return(text);
}

/* create error text for bug reports */
function sendJSError(scripturl, text) {
    if(text && window.XMLHttpRequest) {
        var xhr = new XMLHttpRequest();
        text = '---------------\nJS-Error:\n'+text+'---------------\n';
        xhr.open("POST", scripturl);
        xhr.setRequestHeader("Content-Type", "text/plain;charset=UTF-8");
        xhr.send(text);
        thruk_errors = [];
    }
    return;
}

/* return shortened string */
function shortenSource(text) {
    if(text.length > 100) {
        return(text.substr(0, 97)+"...\n");
    }
    return(text+"\n");
}

/* update recurring downtime type select */
function update_recurring_type_select(select_id) {
    var sel = document.getElementById(select_id);
    if(!sel) {
        return;
    }
    var val = sel.options[sel.selectedIndex].value;
    hideElement('input_host');
    hideElement('input_host_options');
    hideElement('input_hostgroup');
    hideElement('input_service');
    hideElement('input_servicegroup');
    if(val == 'Host') {
        showElement('input_host');
        showElement('input_host_options');
    }
    if(val == 'Hostgroup') {
        showElement('input_hostgroup');
        showElement('input_host_options');
    }
    if(val == 'Service') {
        showElement('input_host');
        showElement('input_service');
    }
    if(val == 'Servicegroup') {
        showElement('input_servicegroup');
    }
    return;
}

/* make table header selectable */
function set_sub(nr) {
    for(x=1;x<=10;x++) {
        /* reset table rows */
        if(x != nr) {
            jQuery('.sub_'+x).css('display', 'none');
        }
        jQuery('.sub_'+nr).css('display', '');

        /* reset buttons */
        obj = document.getElementById("sub_"+x);
        if(obj) {
            styleElements(obj, "data", 1);
        }
    }
    obj = document.getElementById("sub_"+nr);
    styleElements(obj, "data dataSelected", 1);


    return false;
}

/* hilight area of screen */
function hilight_area(x1, y1, x2, y2, duration, color) {
    if(!color)    { color    = 'red'; };
    if(!duration) { duration = 2000; };
    var rnd = Math.floor(Math.random()*10000000);

    jQuery(document.body).append('<div id="hilight_area'+rnd+'" style="width:'+(x2-x1)+'px; height:'+(y2-y1)+'px; position: absolute; background-color: '+color+'; opacity:0.2; top: '+y1+'px; left: '+x1+'px; z-index:10000;">&nbsp;<\/div>');

    window.setTimeout(function() {
       fade('hilight_area'+rnd, 1000);
    }, duration);
}

/* fade out using jquery ui, ensure jquery ui loaded */
function fade(id, duration) {
    var success = function(script, textStatus, jqXHR) {
        jQuery('#'+id).hide('fade', {}, duration);
    };

    if(has_jquery_ui) {
        success();
    } else {
        load_jquery_ui(success);
    }

    // completly remove message from dom after fading out
    if(id == 'thruk_message') {
        window.setTimeout("jQuery('#"+id+"').remove()", duration + 1000);
    }
}

var ui_loading = false;
function load_jquery_ui(callback) {
    if(has_jquery_ui || ui_loading) {
        return;
    }
    var css  = document.createElement('link');
    css.href = jquery_ui_css;
    css.rel  = 'stylesheet';
    css.type = 'text/css';
    document.body.appendChild(css);
    ui_loading = true;
    jQuery.ajax({
        url:       jquery_ui_url,
        dataType: 'script',
        success:   function(script, textStatus, jqXHR) {
            has_jquery_ui = true;
            callback(script, textStatus, jqXHR);
            ui_loading = false;
        },
        cache:     true
    });
}


/* write/return table with performance data */
var thruk_message_fade_timer;
function thruk_message(rc, message, close_timeout) {
    jQuery('#thruk_message').remove();
    window.clearInterval(thruk_message_fade_timer);
    cls = 'fail_message';
    if(rc == 0) { cls = 'success_message'; }
    var html = ''
        +'<div id="thruk_message" class="thruk_message '+cls+'" style="position: fixed; z-index: 5000; width: 600px; top: 30px; left: 50%; margin-left:-300px;">'
        +'  <div class="shadow"><div class="shadowcontent">'
        +'  <table cellspacing=2 cellpadding=0 width="100%" style="background: #F0F1EE; border: 1px solid black">'
        +'    <tr>'
        +'      <td align="center">'
        +'        <span class="' + cls + '">' + message + '<\/span>';
    if(rc != 0) {
        html += ''
        +'          <img src="' + url_prefix + 'themes/'+ theme +'/images/error.png" alt="Errors detected" title="Errors detected" width="16" height="16" style="vertical-align: text-bottom">'
    }
    html += ''
        +'      <\/td>'
        +'      <td valign="top" align="right" width="50">'
        +'        <a href="#" onclick="fade(\'thruk_message\', 500);return false;"><img src="' + url_prefix + 'themes/' + theme + '/images/icon_close.gif" border="0" alt="Hide Message" title="Hide Message" width="13" height="12" class="close_button" style="margin-right: 4px;"><\/a>'
        +'      <\/td>'
        +'    <\/tr>'
        +'  <\/table>'
        +'  <\/div><\/div>';

    jQuery("body").append(html);
    var fade_away_in = 5000;
    if(rc != 0) {
        fade_away_in = 30000;
    }
    if(close_timeout != undefined) {
        if(close_timeout == 0) {
            return;
        }
        fade_away_in = close_timeout * 1000;
    }
    thruk_message_fade_timer = window.setTimeout("fade('thruk_message', 500)", fade_away_in);
}

/* return absolute host part of current url */
function get_host() {
    var host = window.location.protocol + '//' + window.location.host;
    if(window.location.port != "" && host.indexOf(':' + window.location.port) == -1) {
        host += ':' + window.location.port;
    }
    return(host);
}

var nohashchange = 0;
function save_url_in_parents_hash() {
    if(nohashchange == 1) {
      nohashchange = 0;
      return;
    }
    var oldloc = new String(window.parent.location);
    oldloc     = oldloc.replace(/#+.*$/, '');
    oldloc     = oldloc.replace(/\?.*$/, '');
    var patt   = new RegExp('\/'+product_prefix+'\/$', 'g');
    if(!oldloc.match(patt)) {
        return;
    }
    var newloc = new String(window.location);
    newloc     = newloc.replace(oldloc, '');
    // changes have to be put in the index.tt too
    newloc     = newloc.replace(/\?_=\d+/g, '');
    newloc     = newloc.replace(/\&_=\d+/g, '');
    newloc     = newloc.replace(/\&reload_nav=\d+/g, '');
    newloc     = newloc.replace(/\?reload_nav=\d+/g, '');
    newloc     = newloc.replace(/\&theme=\w*/g, '');
    newloc     = newloc.replace(/\?theme=\w*/g, '');
    newloc     = newloc.replace(/nav=\&/g, '');
    newloc     = newloc.replace(/\&service_columns=\d+/g, '');
    newloc     = newloc.replace(/\&host_columns=\d+/g, '');
    newloc     = newloc.replace(/\&bookmarks=.*?\&/g, '&');
    newloc     = newloc.replace(/\&bookmarksp=.*?\&/g, '&');
    newloc     = newloc.replace(/\&section=.*?\&/g, '&');
    newloc     = newloc.replace(/\&update\.x=\d+/g, '');
    newloc     = newloc.replace(/\&update\.y=\d+/g, '');
    newloc     = newloc.replace(/\&newname=\&/g, '&');
    newloc     = newloc.replace(/\&view_mode=html\&/g, '&');
    newloc     = newloc.replace(/\&all_col=\&/g, '&');
    newloc     = newloc.replace(/\&bookmark=.*?\&/g, '&');
    newloc     = newloc.replace(/\&referer=.*?\&/g, '&');
    var patt   = new RegExp('^' + get_host(), 'gi');
    newloc     = newloc.replace(patt, '');
    if('#'+newloc != window.parent.location.hash) {
        if(window.parent.history.replaceState) {
            window.parent.history.replaceState({}, "", '#'+newloc);
        } else {
            nohashchange = 1;
            // do not use window.parent.location.replace, as this causes
            // IE to reload the frame page and then the navigation disapears
            window.parent.location.hash = '#'+newloc;
        }
        window.setTimeout("nohashchange=0", 100);
    }
    return;
}

/* set hash of url */
function set_hash(value, nr) {
    if(value == undefined)   { value = ""; }
    if(value == "undefined") { value = ""; }
    var current = get_hash();
    if(nr != undefined) {
        if(current == undefined) {
            current = "";
        }
        var tmp   = current.split('|');
        tmp[nr-1] = value;
        value     = tmp.join('|');
    }
    // make emtpy values nicer, trim trailing pipes
    value = value.replace(/\|$/, '');

    // replace history otherwise we have to press back twice
    if(current == value) { return; }
    if(value == "") {
        value = getCurrentUrl(false).replace(/\#.*$/, "");
    } else {
        value = '#'+value;
    }
    if (history.replaceState) {
        history.replaceState({}, "", value);
    } else {
        window.location.replace(value);
    }
    if(window.parent) {
        try {
            save_url_in_parents_hash();
        } catch(err) { debug(err); }
    }
}

/* get hash of url */
function get_hash(nr) {
    var hash;
    if(window.location.hash != '#') {
        var values = window.location.hash.split("/");
        if(values[0]) {
            hash = values[0].replace(/^#/, '');
        }
    }
    if(nr != undefined) {
        if(hash == undefined) {
            hash = "";
        }
        var tmp = hash.split('|');
        return(tmp[nr-1]);
    }
    return(hash);
}

function preserve_hash() {
    // save hash value for 30 seconds
    cookieSave('thruk_preserve_hash', get_hash(), 60);
}

/* fetch content by ajax and replace content */
function load_overlib_content(id, url, add_pre) {
    jQuery.ajax({
        url: url,
        type: 'POST',
        success: function(data) {
            var el = document.getElementById(id);
            if(el) {
                if(add_pre) {
                    data.data = "<pre>"+data.data+"<\/pre>";
                }
                el.innerHTML = data.data;
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            debug(textStatus);
        }
    });
}

/* update permanent link of excel export */
function updateExcelPermanentLink() {
    var inp  = jQuery('#excel_export_url');
    var data = jQuery(inp).parents('FORM').find('input[name!=bookmark][name!=referer][name!=view_mode][name!=all_col]').serialize();
    var base = jQuery('#excelexportlink')[0].href;
    base = cleanUnderscore(base);
    if(!data) {
        jQuery(inp).val(base);
        return;
    }
    jQuery(inp).val(base + (base.match(/\?/) ? '&' : '&') + data);
    initExcelExportSorting();
}

/* compare two objects and print diff
 * returns true if they differ and false if they are equal
 */
function obj_diff(o1, o2, prefix) {
    if(prefix == undefined) { prefix = ""; }
    if(typeof(o1) != typeof(o2)) {
        debug("type is different: a" + prefix + " "+typeof(o1)+"       b" + prefix + " "+typeof(o2));
        return(true);
    }
    else if(is_array(o1)) {
        for(var nr=0; nr<o1.length; nr++) {
            if(obj_diff(o1[nr], o2[nr], prefix+"["+nr+"]")) {
                return(true);
            }
        }
    }
    else if(typeof(o1) == 'object') {
        for(var key in o1) {
            if(obj_diff(o1[key], o2[key], prefix+"["+key+"]")) {
                return(true);
            }
        }
    } else if(typeof(o1) == 'string' || typeof(o1) == 'number' || typeof(o1) == 'boolean') {
        if(o1 != o2) {
            debug("value is different: a" + prefix + " "+o1+"       b" + prefix + " "+o2);
            return(true);
        }
    } else {
        debug("don't know how to compare: "+typeof(o1)+" at a"+prefix);
    }
    return(false);
}

/* callback to show popup with host comments */
function host_comments_popup(host_name, peer_key) {
    generic_downtimes_popup(host_name+' Comments', url_prefix+'cgi-bin/parts.cgi?part=_host_comments&host='+encodeURIComponent(host_name)+"&backend="+peer_key);
}

/* callback to show popup with host downtimes */
function host_downtimes_popup(host_name, peer_key) {
    generic_downtimes_popup(host_name+' Downtimes', url_prefix+'cgi-bin/parts.cgi?part=_host_downtimes&host='+encodeURIComponent(host_name)+"&backend="+peer_key);
}

/* callback to show popup with service comments */
function service_comments_popup(host_name, service, peer_key) {
    generic_downtimes_popup(host_name+' - '+service+' Comments', url_prefix+'cgi-bin/parts.cgi?part=_service_comments&host='+encodeURIComponent(host_name)+'&service='+encodeURIComponent(service)+"&backend="+peer_key);
}

/* callback to show popup with service downtimes */
function service_downtimes_popup(host_name, service, peer_key) {
    generic_downtimes_popup(host_name+' - '+service+' Downtimes', url_prefix+'cgi-bin/parts.cgi?part=_service_downtimes&host='+encodeURIComponent(host_name)+'&service='+encodeURIComponent(service)+"&backend="+peer_key);
}

/* callback to show popup host/service downtimes */
function generic_downtimes_popup(title, url) {
    var content = "<div id='comments_downtimes_popup'><img src='"+url_prefix + 'themes/' + theme + '/images/loading-icon.gif'+"'><\/div>";
    var options = [content, CAPTION, title,WIDTH,600];
    options = options.concat(info_popup_options);
    overlib.apply(this, options);
    jQuery('#comments_downtimes_popup').load(url);
}

function fetch_long_plugin_output(td, host, service, backend, escape_html) {
    jQuery('.long_plugin_output').html("<img src='"+url_prefix + 'themes/' + theme + '/images/loading-icon.gif'+"'><\/div>");
    var url = url_prefix+'cgi-bin/status.cgi?long_plugin_output=1&host='+host+"&service="+service+"&backend="+backend;
    if(escape_html) {
        jQuery.get(url, {}, function(text, status, req) {
            text = jQuery("<div>").text(text).html().replace(/\\n/g, "<br>");
            jQuery('.long_plugin_output').html(text)
        });
    } else {
        jQuery('.long_plugin_output').load(url, {}, function(text, status, req) {
        });
    }
}

function initExcelExportSorting() {
    if(!has_jquery_ui) {
        load_jquery_ui(function() {
            initExcelExportSorting();
        });
        return;
    }
    if(already_sortable["excel_export"]) {
        return;
    }
    already_sortable["excel_export"] = true;

    jQuery('TABLE.sortable_col_table').sortable({
        items                : 'TR.sortable_row',
        helper               : 'clone',
        tolerance            : 'pointer',
        update               : function( event, ui ) {
            updateExcelPermanentLink();
        }
    });
}

// make the columns sortable
var already_sortable = {};
function initStatusTableColumnSorting(pane_prefix, table_id) {
    if(!has_jquery_ui) {
        load_jquery_ui(function() {
            initStatusTableColumnSorting(pane_prefix, table_id);
        });
        return;
    }
    if(already_sortable[pane_prefix]) {
        return;
    }
    already_sortable[pane_prefix] = true;

    jQuery('#'+table_id+' > tbody > tr:first-child').sortable({
        items                : '> th',
        helper               : 'clone',
        tolerance            : 'pointer',
        update               : function( event, ui ) {
            var oldIndexes = []
            var rowsToSort = {};
            var table;
            // remove all current rows from the column selector, they will be later readded in the right order
            jQuery('#'+pane_prefix+'_columns_table > tbody > tr').each(function(i, el) {
                table = el.parentNode;
                var row = el.parentNode.removeChild(el);
                var field = jQuery(row).find("input").val();
                rowsToSort[field] = row;
                oldIndexes.push(field);
            });
            // fetch the target column order based on the current status table header
            var target = [];
            jQuery('#'+table_id+' > tbody > tr:first-child > th').each(function(i, el) {
                var col = get_column_from_classname(el);
                if(col) {
                    target.push(col);
                }
            });
            jQuery(target).each(function(i, el) {
                table.appendChild(rowsToSort[el]);
            });
            // remove the current column header and readd them in original order, so later ordering wont skip headers
            var currentHeader = {};
            jQuery('#'+table_id+' > tbody > tr:first-child > th').each(function(i, el) {
                table = el.parentNode;
                var row = el.parentNode.removeChild(el);
                var col = get_column_from_classname(el);
                if(col) {
                    currentHeader[col] = row;
                }
            });
            jQuery(oldIndexes).each(function(i, el) {
                table.appendChild(currentHeader[el]);
            });
            updateStatusColumns(pane_prefix, false);
        }
    });
    jQuery('#'+pane_prefix+'_columns_table tbody').sortable({
        items                : '> tr',
        placeholder          : 'column-sortable-placeholder',
        update               : function( event, ui ) {
            /* drag/drop changes the checkbox state, so set checked flag assuming that a moved column should be visible */
            window.setTimeout(function() {
                jQuery(ui.item[0]).find("input").prop('checked', true);
                updateStatusColumns(pane_prefix, false);
            }, 100);
        }
    });
    /* enable changing columns header name */
    jQuery('#'+table_id+' > tbody > tr:first-child > th').dblclick(function(evt) {
        var th = evt.target;
        var text   = (th.innerText || '').replace(/\s*$/, '');
        var childs = removeChilds(th);
        th.innerHTML = "<input type='text' class='header_inline_edit' value='"+text+"'></form>";
        window.setTimeout(function() {
            jQuery(th).find('INPUT').focus();
            var input = jQuery(th).find('INPUT')[0];
            setCaretToPos(input, text.length);
            jQuery(input).on('keyup blur', function (e) {
                /* submit on enter/return */
                if(e.keyCode == 13 || e.type == "blur") {
                    th.innerHTML = escapeHTML(input.value)+" ";
                    // restore sort links
                    addChilds(th, childs, 1);
                    var col  = get_column_from_classname(th);
                    var orig = jQuery('#'+pane_prefix+'_col_'+col)[0].title;

                    var cols = default_columns[pane_prefix];
                    if(additionalParams[pane_prefix+'columns']) {
                        cols = additionalParams[pane_prefix+'columns'];
                    }
                    cols = cols.split(/,/);
                    for(var x = 0; x < cols.length; x++) {
                        var tmp = cols[x].split(/:/, 2);
                        if(tmp[0] == col) {
                            if(orig != input.value) {
                                cols[x] = tmp[0]+':'+input.value;
                            } else {
                                cols[x] = tmp[0];
                            }
                        }
                    }

                    jQuery('#'+pane_prefix+'_col_'+col+'n')[0].innerHTML = input.value;

                    var newVal = cols.join(',');
                    jQuery('#'+pane_prefix+'columns').val(newVal);
                    additionalParams[pane_prefix+'columns'] = newVal;
                    updateUrl();
                }
                /* cancel on escape */
                if(e.keyCode == 27) {
                    th.innerHTML = text+" ";
                    // restore sort links
                    addChilds(th, childs, 1);
                }
            });
        }, 100);
    });
    /* enable changing columns header name */
    jQuery('#'+pane_prefix+'_columns_table tbody td.filterName').dblclick(function(evt) {
        var th = evt.target;
        var text   = (th.innerText || '').replace(/\s*$/, '');
        th.innerHTML = "<input type='text' class='header_inline_edit' value='"+text+"'></form>";
        window.setTimeout(function() {
            jQuery(th).find('INPUT').focus();
            var input = jQuery(th).find('INPUT')[0];
            setCaretToPos(input, text.length);
            jQuery(input).on('keydown blur', function (e) {
                /* submit on enter/return */
                if(e.keyCode == 13 || e.type == "blur") {
                    e.preventDefault();
                    th.innerHTML = escapeHTML(input.value);
                    var col  = get_column_from_classname(th);
                    var orig = jQuery('#'+pane_prefix+'_col_'+col)[0].title;

                    var cols = default_columns[pane_prefix];
                    if(additionalParams[pane_prefix+'columns']) {
                        cols = additionalParams[pane_prefix+'columns'];
                    }
                    cols = cols.split(/,/);
                    for(var x = 0; x < cols.length; x++) {
                        var tmp = cols[x].split(/:/, 2);
                        if(tmp[0] == col) {
                            if(orig != input.value) {
                                cols[x] = tmp[0]+':'+input.value;
                            } else {
                                cols[x] = tmp[0];
                            }
                        }
                    }

                    var header = jQuery('.'+pane_prefix+'_table').find('th.status.col_'+col)[0];
                    var childs = removeChilds(header);
                    header.innerHTML = input.value+" ";
                    addChilds(header, childs, 1);

                    var newVal = cols.join(',');
                    jQuery('#'+pane_prefix+'columns').val(newVal);
                    additionalParams[pane_prefix+'columns'] = newVal;
                    updateUrl();
                }
                /* cancel on escape */
                if(e.keyCode == 27) {
                    e.preventDefault();
                    th.innerHTML = text+" ";
                }
            });
        }, 100);
    });
}

// remove and return all child nodes
function removeChilds(el) {
    var childs = [];
    while(el.firstChild) {
        childs.push(el.removeChild(el.firstChild));
    }
    return(childs);
}

// add all elements as child
function addChilds(el, childs, startWith) {
    if(startWith == undefined) { startWith = 0; }
    for(var x = startWith; x < childs.length; x++) {
        el.appendChild(childs[x]);
    }
}

/* returns the value of the col_.* class */
function get_column_from_classname(el) {
    var classes = el.className.split(/\s+/);
    for(var x = 0; x < classes.length; x++) {
        var m = classes[x].match(/^col_(.*)$/);
        if(m && m[1]) {
            return(m[1]);
        }
    }
    return;
}

// apply status table columns
function updateStatusColumns(id, reloadRequired) {
    resetRefresh();
    var table = jQuery('.'+id+'_table')[0];
    if(!table) {
        if(thruk_debug_js) { alert("ERROR: no table found in updateStatusColumns(): " + id); }
    }
    var changed = false;
    if(reloadRequired == undefined) { reloadRequired = true; }
    table.style.visibility = "hidden";

    removeParams['autoShow'] = true;

    var firstRow = table.rows[0];
    var firstDataRow = [];
    if(table.rows.length > 1) {
        firstDataRow = table.rows[1];
    }
    var selected = [];
    jQuery('.'+id+'_col').each(function(i, el) {
        if(!jQuery(firstRow.cells[i]).hasClass("col_"+el.value)) {
            // need to reorder column
            var targetIndex = i;
            var sourceIndex;
            jQuery(firstRow.cells).each(function(j, c) {
                if(jQuery(c).hasClass("col_"+el.value)) {
                    sourceIndex = j;
                    return false;
                }
            });
            var dataSourceIndex;
            jQuery(firstDataRow.cells).each(function(j, c) {
                if(jQuery(c).hasClass(el.value)) {
                    dataSourceIndex = j;
                    return false;
                }
            });
            if(sourceIndex == undefined && !reloadRequired) {
                if(thruk_debug_js) { alert("ERROR: unknown header column in updateStatusColumns(): " + el.value); }
                return;
            }
            if(firstDataRow.cells && dataSourceIndex == undefined) {
                reloadRequired = true;
            }
            if(sourceIndex) {
                if(firstRow.cells[sourceIndex]) {
                    var cell = firstRow.removeChild(firstRow.cells[sourceIndex]);
                    firstRow.insertBefore(cell, firstRow.cells[targetIndex]);
                }
                changed = true;
            }
            if(dataSourceIndex) {
                jQuery(table.rows).each(function(j, row) {
                    if(j > 0 && row.cells[dataSourceIndex]) {
                        var cell = row.removeChild(row.cells[dataSourceIndex]);
                        row.insertBefore(cell, row.cells[targetIndex]);
                    }
                });
                changed = true;
            }
        }

        // adjust table header text
        var current   = (firstRow.cells[i].innerText || '').trim();
        var newHeadEl = document.getElementById(el.id+'n');
        if(!newHeadEl) {
            if(thruk_debug_js) { alert("ERROR: header element not found in updateStatusColumns(): " + el.id+'n'); }
            table.style.visibility = "visible";
            return;
        }
        var newHead = newHeadEl.innerHTML.trim();
        if(current != newHead) {
            var childs = removeChilds(firstRow.cells[i]);
            firstRow.cells[i].innerHTML = newHead+" ";
            addChilds(firstRow.cells[i], childs, 1);
            changed = true;
        }

        // check visibility of this column
        var display = "none";
        if(el.checked) {
            display = "";
            if(newHead != el.title) {
                selected.push(el.value+':'+newHead);
            } else {
                selected.push(el.value);
            }
        }
        if(table.rows[0].cells[i].style.display != display) {
            changed = true;
            jQuery(table.rows).each(function(j, row) {
                if(row.cells[i]) {
                    row.cells[i].style.display = display;
                }
            });
        }
    });
    if(changed) {
        var newVal = selected.join(",");
        if(newVal != default_columns[id]) {
            jQuery('#'+id+'columns').val(newVal);
            additionalParams[id+'columns'] = newVal;
            delete removeParams[id+'columns'];

            if(reloadRequired && table.rows[1] && table.rows[1].cells.length < 10) {
                additionalParams["autoShow"] = id+"_columns_select";
                delete removeParams['autoShow'];
                jQuery('#'+id+"_columns_select").find("DIV.shadowcontent").append("<div class='overlay'></div>").append("<div class='overlay-text'><img class='overlay' src='"+url_prefix + 'themes/' +  theme + "/images/loading-icon.gif'><br>fetching table...</div>");
                table.style.visibility = "visible";
                reloadPage();
                return;
            }
        } else {
            jQuery('#'+id+'columns').val("");
            delete additionalParams[id+'columns'];
            removeParams[id+'columns'] = true;
        }
        updateUrl();
    }
    table.style.visibility = "visible";
}

/* reload page with with sorting parameters set */
function sort_by_columns(args) {
    for(var key in args) {
        additionalParams[key] = args[key];
    }
    reloadPage();
    return(false);
}

function setDefaultColumns(type, pane_prefix, value) {
    updateUrl();
    if(value == undefined) {
        var urlArgs  = toQueryParams();
        value = urlArgs[pane_prefix+"columns"];
    }

    var data = {
        action:  'set_default_columns',
        type:    type,
        value:   value,
        token:   user_token
    };
    jQuery.ajax({
        url: "status.cgi",
        data: data,
        type: 'POST',
        success: function(data) {
            thruk_message(data.rc, data.msg);
            if(value == "") {
                jQuery("."+pane_prefix+"_reset_columns_btn").attr({disabled: true});
                removeParams[pane_prefix+'columns'] = true;
                reloadPage();
            } else {
                jQuery("."+pane_prefix+"_reset_columns_btn").attr({disabled: false});
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            thruk_message(1, 'setting default failed: '+ textStatus);
        }
    });
    return(false);
}

function refreshNavSections(id) {
    jQuery.ajax({
        url: "status.cgi?type=navsection&format=search",
        type: 'POST',
        success: function(data) {
            if(data && data[0]) {
                jQuery('#'+id).find('option').remove();
                jQuery('#'+id).append(jQuery('<option>', {
                    value: 'Bookmarks',
                    text : 'Bookmarks'
                }));
                jQuery.each(data[0].data, function (i, item) {
                    if(item != "Bookmarks") {
                        jQuery('#'+id).append(jQuery('<option>', {
                            value: item,
                            text : item
                        }));
                    }
                });
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            thruk_message(1, 'fetching side nav sections failed: '+ textStatus);
        }
    });
    return(false);
}

function broadcast_show_list(incr) {
    var broadcasts = jQuery(".broadcast_panel_container div.broadcast");
    var curIdx = 0;
    jQuery(broadcasts).each(function(i, n) {
        if(jQuery(n).is(":visible")) {
            jQuery(n).hide();
            curIdx = i;
            return(false);
        }
    });
    var newIdx = curIdx+incr;
    jQuery(broadcasts[newIdx]).show();
    jQuery(".broadcast_panel_container BUTTON.next").css('visibility', '');
    jQuery(".broadcast_panel_container BUTTON.previous").css('visibility', '');
    if(newIdx == broadcasts.length -1) {
        jQuery(".broadcast_panel_container BUTTON.next").css('visibility', 'hidden');
    }
    if(newIdx == 0) {
        jQuery(".broadcast_panel_container BUTTON.previous").css('visibility', 'hidden');
    }
}

function broadcast_dismiss() {
    jQuery('.broadcast_panel_container').hide();
    jQuery.ajax({
        url: url_prefix + 'cgi-bin/broadcast.cgi',
        data: {
            action: 'dismiss',
            token:  user_token
        },
        type: 'POST',
        success: function(data) {},
        error: function(jqXHR, textStatus, errorThrown) {
            thruk_message(1, 'marking broadcast as read failed: '+ textStatus);
        }
    });
    return(false);
}

function looks_like_regex(str) {
    if(str != undefined && str != null && str.match(/[\^\|\*\{\}\[\]]/)) {
        return(true);
    }
    return(false);
}

function show_list(incr, selector) {
    var elements = jQuery(selector);
    var curIdx = 0;
    jQuery(elements).each(function(i, n) {
        if(jQuery(n).is(":visible")) {
            jQuery(n).hide();
            curIdx = i;
            return(false);
        }
    });
    var newIdx = curIdx+incr;
    jQuery(elements[newIdx]).show();
    jQuery("DIV.controls BUTTON.next").css('visibility', '');
    jQuery("DIV.controls BUTTON.previous").css('visibility', '');
    if(newIdx == elements.length -1) {
        jQuery("DIV.controls BUTTON.next").css('visibility', 'hidden');
    }
    if(newIdx == 0) {
        jQuery("DIV.controls BUTTON.previous").css('visibility', 'hidden');
    }
}

/* split that works more like the perl split and appends the remaining str to the last element, doesn't work with regex */
function splitN(str, separator, limit) {
    str = str.split(separator);

    if(str.length > limit) {
        var ret = str.splice(0, limit);
        ret.push(ret.pop()+separator+str.join(separator));

        return ret;
    }

    return str;
}

/*******************************************************************************
*        db        ,ad8888ba, 888888888888 88   ,ad8888ba,   888b      88
*       d88b      d8"'    `"8b     88      88  d8"'    `"8b  8888b     88
*      d8'`8b    d8'               88      88 d8'        `8b 88 `8b    88
*     d8'  `8b   88                88      88 88          88 88  `8b   88
*    d8YaaaaY8b  88                88      88 88          88 88   `8b  88
*   d8""""""""8b Y8,               88      88 Y8,        ,8P 88    `8b 88
*  d8'        `8b Y8a.    .a8P     88      88  Y8a.    .a8P  88     `8888
* d8'          `8b `"Y8888Y"'      88      88   `"Y8888Y"'   88      `888
*******************************************************************************/

/* print the action menu icons and action icons */
var menu_nr = 0;
function print_action_menu(src, backend, host, service, orientation, show_title) {
    try {
        if(orientation == undefined) { orientation = 'b-r'; }
        if(typeof src === "function") {
            src = src({config: null, submenu: null, menu_id: 'actionmenu_'+menu_nr, backend: backend, host: host, service: service})
        }
        src = is_array(src) ? src : [src];
        jQuery(src).each(function(i, el) {
            var icon       = document.createElement('img');
            var icon_url   = replace_macros(el.icon);
            icon.src       = icon_url;
            try {
                // use data url in reports
                if(action_images[icon_url]) {
                    icon.src = action_images[icon_url];
                }
            } catch(e) {}
            icon.className = 'action_icon '+(el.menu || el.action ? 'clickable' : '' );
            if(el.menu) {
                icon.nr = menu_nr;
                jQuery(icon).bind("click", function() {
                    /* open and show menu */
                    show_action_menu(icon, el.menu, icon.nr, backend, host, service, orientation);
                });
                menu_nr++;
            }
            var item = icon;

            if(el.action) {
                var link = document.createElement('a');
                link.href = replace_macros(el.action);
                if(el.target) { link.target = el.target; }
                link.appendChild(icon);
                item = link;
            }

            /* apply other attributes */
            set_action_menu_attr(item, el, backend, host, service, function() {
                // must be added as callback, otherwise the order of the binds gets mixed up and "onclick confirms" would be called after the click itself
                if(el.action) {
                    check_server_action(undefined, item, backend, host, service, undefined, undefined, undefined, el);
                }
            });

            /* obtain reference to current script tag so we could insert the icons here */
            var scriptTag = document.scripts[document.scripts.length - 1];
            scriptTag.parentNode.appendChild(item);
            if(show_title && el.title) {
                var title = document.createTextNode(icon.title);
                scriptTag.parentNode.appendChild(title);
            }
        });
    }
    catch(err) {
        document.write('<img src="'+ url_prefix +'themes/'+ theme +'/images/error.png" title="'+err+'">');
    }
}

/* set a single attribute for given item/link */
function set_action_menu_attr(item, data, backend, host, service, callback) {
    var toReplace = {};
    for(var key in data) {
        // those key are handled separately already
        if(key == "icon" || key == "action" || key == "menu" || key == "label") {
            continue;
        }

        var attr = data[key];
        if(String(attr).match(/\$/)) {
            toReplace[key] = attr;
            continue;
        }
        if(key.match(/^on/)) {
            if(!data.disabled) {
                var cmd = attr;
                jQuery(item).bind(key.substring(2), {cmd: cmd}, function(evt) {
                    var cmd = evt.data.cmd;
                    var res = new Function(cmd)();
                    if(!res) {
                        /* cancel default/other binds when callback returns false */
                        evt.stopImmediatePropagation();
                    }
                    return(res);
                });
            }
        } else {
            item[key] = attr;
        }
    }
    if(Object.keys(toReplace).length > 0) {
        jQuery.ajax({
            url: url_prefix + 'cgi-bin/status.cgi?replacemacros=1',
            data: {
                host:     host,
                service:  service,
                backend:  backend,
                dataJson: JSON.stringify(toReplace),
                token:    user_token
            },
            type: 'POST',
            success: function(data) {
                if(data.rc != 0) {
                    thruk_message(1, 'could not replace macros: '+ data.data);
                } else {
                    set_action_menu_attr(item, data.data, backend, host, service, callback);
                    callback();
                }
            },
            error: function(jqXHR, textStatus, errorThrown) {
                thruk_message(1, 'could not replace macros: '+ textStatus);
            }
        });
    } else {
        callback();
    }
}

/* renders the action menu when openend */
function show_action_menu(icon, items, nr, backend, host, service, orientation) {
    resetRefresh();

    var id = 'actionmenu_'+nr;
    var container = document.getElementById(id);
    if(container) {
        // always recreate the menu
        container.parentNode.removeChild(container);
        container = null;
    }

    window.setTimeout(function() {
        // otherwise the reset comes before we add our new class
        jQuery(icon).addClass('active');
    }, 30);

    if(container) {
        return;
    }

    container               = document.createElement('div');
    container.className     = 'action_menu';
    container.id            = id;
    container.style.visible = 'hidden';

    var s1 = document.createElement('div');
    container.appendChild(s1);
    s1.className = 'shadow';

    var s2 = document.createElement('div');
    s2.className = 'shadowcontent';
    s1.appendChild(s2);

    var menu = document.createElement('ul');
    s2.appendChild(menu);
    menu.className = 'action_menu';

    if(typeof(items) === "function") {
        menu.appendChild(actionGetMenuItem({icon: url_prefix+'themes/'+theme+'/images/waiting.gif', label: 'loading...'}, id, backend, host, service));
        jQuery.when(items({config: null, submenu: menu, menu_id: id, backend: backend, host: host, service: service}))
        .done(function(data) {
            removeChilds(menu);
            if(!data || !is_array(data)) { return; }
            jQuery(data).each(function(i, submenuitem) {
                menu.appendChild(actionGetMenuItem(submenuitem, id, backend, host, service));
            });
            check_position_and_show_action_menu(id, icon, container, orientation);
            return;
        });
    } else {
        jQuery(items).each(function(i, el) {
            menu.appendChild(actionGetMenuItem(el, id, backend, host, service));
        });
    }

    document.body.appendChild(container);
    check_position_and_show_action_menu(id, icon, container, orientation);
}

function actionGetMenuItem(el, id, backend, host, service) {
    var item = document.createElement('li');
    if(el == "-") {
        var hr = document.createElement('hr');
        item.appendChild(hr);
        item.className = 'nohover';
        return(item);
    }

    if(el.disabled) {
        item.className = 'clickable disabled nohover';
    } else {
        item.className = 'clickable';
    }
    var link = document.createElement('a');
    if(el.icon) {
        var span       = document.createElement('span');
        span.className = 'icon';
        var img        = document.createElement('img');
        img.src        = replace_macros(el.icon);
        img.title      = el.title ? el.title : '';
        span.appendChild(img);
        link.appendChild(span);
    }

    var label;
    if(el.html) {
        label = document.createElement('span');
        label.innerHTML = el.html;
    } else {
        label = document.createElement('span');
        label.innerHTML = el.label;
    }
    link.appendChild(label);

    if(el.action && !el.disabled) {
        if(typeof el.action === "function") {
            jQuery(link).bind("click", {backend: backend, host: host, service: service}, el.action);
        } else {
            link.href = replace_macros(el.action);
        }
    }
    if(el.menu) {
        link.className = link.className+' hasSubMenu';
        var expandLabel = document.createElement('span');
        expandLabel.className = "expandable";
        expandLabel.innerHTML = "&gt;";
        link.appendChild(expandLabel);
        var submenu = document.createElement('ul');
        submenu.className = "action_menu submenu";
        submenu.style.display = 'none';
        item.appendChild(submenu);
        item.style.position = 'relative';
        jQuery(link).bind("mouseover", function() {
            expandActionSubMenu(item, el, submenu, id, backend, host, service);
        });
    }
    jQuery(link).bind("mouseover", function() {
        // hide all submenus (unless required)
        jQuery('#'+id+' .submenu').each(function(i, s) {
            if(s.parentNode != item) {
                s.required = false;
            }
        });
        var p = link;
        while(p.parentNode && p.id != id) {
            if(jQuery(p).hasClass('submenu')) {
                p.required = true;
            }
            p = p.parentNode;
        }
        jQuery('#'+id+' .submenu').each(function(i, s) {
            if(!s.required) {
                s.ready = false;
                removeChilds(s);
                s.style.display = "none";
            }
        });
    });

    item.appendChild(link);

    /* apply other attributes */
    set_action_menu_attr(link, el, backend, host, service, function() {
        // must be added as callback, otherwise the order of the binds gets mixed up and "onclick confirms" would be called after the click itself
        check_server_action(id, link, backend, host, service, undefined, undefined, undefined, el);
    });
    return(item);
}

function expandActionSubMenu(parent, el, submenu, id, backend, host, service) {
    if(submenu.ready) { return; }

    submenu.required = true;
    submenu.ready = true;
    if(is_array(el.menu)) {
        jQuery(el.menu).each(function(i, submenuitem) {
            submenu.appendChild(actionGetMenuItem(submenuitem, id, backend, host, service));
        });
        submenu.style.display = "";
        checkSubMenuPosition(id, parent, submenu);
        return;
    }

    if(typeof el.menu !== "function") {
        return;
    }
    submenu.appendChild(actionGetMenuItem({icon: url_prefix+'themes/'+theme+'/images/waiting.gif', label: 'loading...'}, id, backend, host, service));
    submenu.style.display = "";
    checkSubMenuPosition(id, parent, submenu);

    jQuery.when(el.menu({config: el, submenu: submenu, menu_id: id, backend: backend, host: host, service: service}))
        .done(function(data) {
            removeChilds(submenu);
            if(!data || !is_array(data)) { return; }
            jQuery(data).each(function(i, submenuitem) {
                submenu.appendChild(actionGetMenuItem(submenuitem, id, backend, host, service));
            });
            checkSubMenuPosition(id, parent, submenu);
            return;
        });
}

function checkSubMenuPosition(id, parent, submenu) {
    var coords = jQuery('#'+id).offset();
    var screenW = jQuery(document).width();
    submenu.style.top  = "-1px";
    if(coords.left > (screenW / 2)) {
        // we are on the right side of the screen, so place it left of the parent
        var w = jQuery(submenu).outerWidth();
        submenu.style.left = (Math.floor(-w)) + "px";
    } else {
        // place right of parent
        var w = jQuery(parent).outerWidth();
        submenu.style.left = (Math.floor(w)-1) + "px";
    }
}

function check_position_and_show_action_menu(id, icon, container, orientation) {
    var coords = jQuery(icon).offset();
    if(orientation == 'b-r') {
        container.style.left = (Math.floor(coords.left)+12) + "px";
    }
    else if(orientation == 'b-l') {
        var w = jQuery(container).outerWidth();
        container.style.left = (Math.floor(coords.left)-w+33) + "px";
    } else {
        if(thruk_debug_js) { alert("ERROR: unknown orientation in show_action_menu(): " + orientation); }
    }
    container.style.top  = (Math.floor(coords.top) + icon.offsetHeight + 14) + "px";

    jQuery('#'+id+' .submenu').css('display', 'none')
    showElement(id, undefined, true, 'DIV#'+id+' DIV.shadowcontent', reset_action_menu_icons);
}

/* set onclick handler for server actions */
function check_server_action(id, link, backend, host, service, server_action_url, extra_param, callback, config) {
    // server action urls
    if(link.href.match(/^server:\/\//)) {
        if(server_action_url == undefined) {
            server_action_url = url_prefix + 'cgi-bin/status.cgi?serveraction=1';
        }
        var data = {
            host:    host,
            service: service,
            backend: backend,
            link:    link.href,
            token:   user_token
        };
        if(extra_param) {
            for(var key in extra_param) {
                data[key] = extra_param[key];
            }
        }
        jQuery(link).bind("click", function() {
            var oldSrc = jQuery(link).find('IMG').attr('src');
            jQuery(link).find('IMG').attr({src:  url_prefix + 'themes/' +  theme + '/images/loading-icon.gif', width: 16, height: 16 }).css('margin', '2px 0px');
            if(config == undefined) { config = {}; }
            jQuery.ajax({
                url: server_action_url,
                data: data,
                type: 'POST',
                success: function(data) {
                    thruk_message(data.rc, data.msg, config.close_timeout);
                    if(id) { remove_close_element(id); jQuery('#'+id).remove(); }
                    reset_action_menu_icons();
                    jQuery(link).find('IMG').attr('src', oldSrc);
                    if(callback) { callback(data); }
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    thruk_message(1, 'server action failed: '+ textStatus, config.close_timeout);
                    if(id) { remove_close_element(id); jQuery('#'+id).remove();  }
                    reset_action_menu_icons();
                    jQuery(link).find('IMG').attr('src', oldSrc);
                }
            });
            return(false);
        });
    }
    // normal urls
    else {
        if(!link.href.match(/\$/)) {
            // no macros, no problems
            return;
        }
        jQuery(link).bind("mouseover", function() {
            if(!link.href.match(/\$/)) {
                // no macros, no problems
                return(true);
            }
            if(link.href.match(/^javascript:/)) {
                // skip javascript links, they will be replace on click
                return(true);
            }
            var href;
            if(link.hasAttribute('orighref')) {
                href = link.getAttribute('orighref');
            } else {
                link.setAttribute('orighref', ""+link.href);
                href = link.getAttribute('href');
            }
            var urlArgs = {
                forward:        1,
                replacemacros:  1,
                host:           host,
                service:        service,
                backend:        backend,
                data:           href
            };
            link.setAttribute('href', url_prefix + 'cgi-bin/status.cgi?'+toQueryString(urlArgs));
            return(true);
        });
        jQuery(link).bind("click", function() {
            if(!link.href.match(/\$/)) {
                // no macros, no problems
                return(true);
            }
            if(!link.href.match(/^javascript:/)) {
                return(true);
            }
            var href;
            if(link.hasAttribute('orighref')) {
                href = link.getAttribute('orighref');
            } else {
                link.setAttribute('orighref', ""+link.href);
                href = link.getAttribute('href');
            }
            jQuery.ajax({
                url: url_prefix + 'cgi-bin/status.cgi?replacemacros=1',
                data: {
                    host:    host,
                    service: service,
                    backend: backend,
                    data:    href,
                    token:   user_token
                },
                type: 'POST',
                success: function(data) {
                    if(data.rc != 0) {
                        thruk_message(1, 'could not replace macros: '+ data.data);
                    } else {
                        link.href = data.data
                        link.click();
                        link.href = link.getAttribute('orighref');
                    }
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    thruk_message(1, 'could not replace macros: '+ textStatus);
                }
            });
            return(false);
        });
    }
}

/* replace common macros */
function replace_macros(input, macros) {
    var out = input;
    if(out == undefined) {
        return(out);
    }
    if(macros != undefined) {
        for(var key in macros) {
            var regex  = new RegExp('\{\{'+key+'\}\}', 'g');
            out = out.replace(regex, macros[key]);
        }
        return(out);
    }

    out = out.replace(/\{\{\s*theme\s*\}\}/g, theme);
    out = out.replace(/\{\{\s*remote_user\s*\}\}/g, remote_user);
    out = out.replace(/\{\{\s*site\s*\}\}/g, omd_site);
    out = out.replace(/\{\{\s*prefix\s*\}\}/g, url_prefix);
    return(out);
}

/* remove active class from action menu icons */
function reset_action_menu_icons() {
    jQuery('IMG.action_icon').removeClass('active');
}

/*******************************************************************************
 * 88888888ba  88888888888 88888888ba  88888888888 88888888ba,        db   888888888888   db
 * 88      "8b 88          88      "8b 88          88      `"8b      d88b       88       d88b
 * 88      ,8P 88          88      ,8P 88          88        `8b    d8'`8b      88      d8'`8b
 * 88aaaaaa8P' 88aaaaa     88aaaaaa8P' 88aaaaa     88         88   d8'  `8b     88     d8'  `8b
 * 88""""""'   88"""""     88""""88'   88"""""     88         88  d8YaaaaY8b    88    d8YaaaaY8b
 * 88          88          88    `8b   88          88         8P d8""""""""8b   88   d8""""""""8b
 * 88          88          88     `8b  88          88      .a8P d8'        `8b  88  d8'        `8b
 * 88          88888888888 88      `8b 88          88888888Y"' d8'          `8b 88 d8'          `8b
*******************************************************************************/
function parse_perf_data(perfdata) {
    var matches   = String(perfdata).match(/([^\s]+|'[^']+')=([^\s]*)/gi);
    var perf_data = [];
    if(!matches) { return([]); }
    for(var nr=0; nr<matches.length; nr++) {
        try {
            var tmp = matches[nr].split(/=/);
            tmp[1] += ';;;;';
            tmp[1]  = tmp[1].replace(/,/g, '.');
            tmp[1]  = tmp[1].replace(/;U;/g, '');
            tmp[1]  = tmp[1].replace(/;U$/g, '');
            var data = tmp[1].match(
                /^(-?\d+(\.\d+)?)([^;]*);(((-?\d+|\d*)(\.\d+)?:)|~:)?((-?\d+|\d*)(\.\d+)?)?;(((-?\d+|\d*)(\.\d+)?:)|~:)?((-?\d+|\d*)(\.\d+)?)?;((-?\d+|\d*)(\.\d+)?)?;((-?\d+|\d*)(\.\d+)?)?;*$/
            );
            data[4]  = (data[4]  != null) ? data[4].replace(/~?:/, '')  : '';
            data[11] = (data[11] != null) ? data[11].replace(/~?:/, '') : '';
            if(tmp[0]) {
                tmp[0]   = tmp[0].replace(/^'/, '');
                tmp[0]   = tmp[0].replace(/'$/, '');
            }
            var d = {
                key:      tmp[0],
                perf:     tmp[1],
                val:      (data[1]  != null && data[1]  != '') ? parseFloat(data[1])  : '',
                unit:      data[3]  != null  ? data[3]  :  '',
                warn_min: (data[4]  != null && data[4]  != '') ? parseFloat(data[4])  : '',
                warn_max: (data[8]  != null && data[8]  != '') ? parseFloat(data[8])  : '',
                crit_min: (data[11] != null && data[11] != '') ? parseFloat(data[11]) : '',
                crit_max: (data[15] != null && data[15] != '') ? parseFloat(data[15]) : '',
                min:      (data[18] != null && data[18] != '') ? parseFloat(data[18]) : '',
                max:      (data[21] != null && data[21] != '') ? parseFloat(data[21]) : ''
            };
            perf_data.push(d);
        } catch(el) {}
    }
    return(perf_data);
}

/* write/return table with performance data */
function perf_table(write, state, plugin_output, perfdata, check_command, pnp_url, is_host, no_title) {
    if(is_host == undefined) { is_host = false; }
    if(is_host && state == 1) { state = 2; } // set critical state for host checks
    var perf_data = parse_perf_data(perfdata);
    var cls       = 'notclickable';
    var result    = '';
    if(perf_data.length == 0) { return false; }
    if(pnp_url != '') {
        cls = 'clickable';
    }
    var res = perf_parse_data(check_command, state, plugin_output, perf_data);
    if(res != null) {
        res = res.reverse();
        for(var nr=0; nr<res.length; nr++) {
            if(res[nr] != undefined) {
                var graph = res[nr];
                result += '<div class="perf_bar_bg '+cls+'" style="width:'+graph.div_width+'px;" '+(no_title ? '' : 'title="'+graph.title+'"')+'>';
                if(graph.warn_width_min != null) {
                    result += '<div class="perf_bar_warn '+cls+'" style="width:'+graph.warn_width_min+'px;">&nbsp;<\/div>';
                }
                if(graph.crit_width_min != null) {
                    result += '<div class="perf_bar_crit '+cls+'" style="width:'+graph.crit_width_min+'px;">&nbsp;<\/div>';
                }
                if(graph.warn_width_max != null) {
                    result += '<div class="perf_bar_warn '+cls+'" style="width:'+graph.warn_width_max+'px;">&nbsp;<\/div>';
                }
                if(graph.crit_width_max != null) {
                    result += '<div class="perf_bar_crit '+cls+'" style="width:'+graph.crit_width_max+'px;">&nbsp;<\/div>';
                }
                result += '<img class="perf_bar" src="' + url_prefix + 'themes/' +  theme + '/images/' + graph.pic + '" style="width:'+ graph.img_width +'px;" '+(no_title ? '' : 'title="'+graph.title+'"')+'>';
                result += '<\/div>';
            }
        }
    }
    if(write) {
        if(result != '' && pnp_url != '') {
            var rel_url = pnp_url.replace('\/graph\?', '/popup?');
            if(perf_bar_pnp_popup == 1) {
                document.write("<a href='"+pnp_url+"' class='tips' rel='"+rel_url+"'>");
            } else {
                document.write("<a href='"+pnp_url+"'>");
            }
        }
        document.write(result);
        if(result != '' && pnp_url != '') {
            document.write("<\/a>");
        }
    }
    return result;
}

/* figures out where warning/critical values should go
 * on the perfbars
 */
function plot_point(value, max, size) {
    return(Math.round((Math.abs(value) / max * 100) / 100 * size));
}

/* return human readable perfdata */
function perf_parse_data(check_command, state, plugin_output, perfdata) {
    var size   = 75;
    var result = [];
    var worst_graphs = {};
    for(var nr=0; nr<perfdata.length; nr++) {
        var d = perfdata[nr];
        if(d.max  == '' && d.unit == '%')     { d.max = 100;        }
        if(d.max  == '' && d.crit_max != '')  { d.max = d.crit_max; }
        if(d.max  == '' && d.warn_max != '')  { d.max = d.warn_max; }
        if(d.val !== '' && d.max  !== '')  {
            var perc       = (Math.abs(d.val) / (d.max-d.min) * 100).toFixed(2);
            if(perc < 5)   { perc = 5;   }
            if(perc > 100) { perc = 100; }
            var pic = 'thermok.png';
            if(state == 1) { var pic = 'thermwarn.png'; }
            if(state == 2) { var pic = 'thermcrit.png'; }
            if(state == 4) { var pic = 'thermgrey.png'; }
            perc = Math.round(perc / 100 * size);
            var warn_perc_min = null;
            if(d.warn_min != '' && d.warn_min > d.min) {
                warn_perc_min = plot_point(d.warn_min, d.max, size);
                if(warn_perc_min == 0) {warn_perc_min = null;}
            }
            var crit_perc_min = null;
            if(d.crit_min != '' && d.crit_min > d.min) {
                crit_perc_min = plot_point(d.crit_min, d.max, size)
                if(crit_perc_min == 0) {crit_perc_min = null;}
                if(crit_perc_min == warn_perc_min) {warn_perc_min = null;}
            }
            var warn_perc_max = null;
            if(d.warn_max != '' && d.warn_max < d.max) {
                warn_perc_max = plot_point(d.warn_max, d.max, size);
                if(warn_perc_max == size) {warn_perc_max = null;}
            }
            var crit_perc_max = null;
            if(d.crit_max != '' && d.crit_max < d.max) {
                crit_perc_max = plot_point(d.crit_max, d.max, size)
                if(crit_perc_max == size) {crit_perc_max = null;}
                if(crit_perc_max == warn_perc_max) {warn_perc_max = null;}
            }
            var graph = {
                title:          d.key + ': ' + perf_reduce(d.val, d.unit) + ' of ' + perf_reduce(d.max, d.unit),
                div_width:      size,
                img_width:      perc,
                pic:            pic,
                field:          d.key,
                val:            d.val,
                warn_width_min: warn_perc_min,
                crit_width_min: crit_perc_min,
                warn_width_max: warn_perc_max,
                crit_width_max: crit_perc_max
            };
            if(worst_graphs[state] == undefined) { worst_graphs[state] = {}; }
            worst_graphs[state][perc] = graph;
            result.push(graph);
        }
    }

    var local_perf_bar_mode = custom_perf_bar_adjustments(perf_bar_mode, result, check_command, state, plugin_output, perfdata);

    if(local_perf_bar_mode == 'worst') {
        if(keys(worst_graphs).length == 0) { return([]); }
        var sortedkeys   = keys(worst_graphs).sort(compareNumeric).reverse();
        var sortedgraphs = keys(worst_graphs[sortedkeys[0]]).sort(compareNumeric).reverse();
        return([worst_graphs[sortedkeys[0]][sortedgraphs[0]]]);
    }
    if(local_perf_bar_mode == 'match') {
        // some hardcoded relations
        if(check_command == 'check_mk-cpu.loads') { return(perf_get_graph_from_result('load15', result)); }
        var matches = plugin_output.match(/([\d\.]+)/g);
        if(matches != null) {
            for(var nr=0; nr<matches.length; nr++) {
                var val = matches[nr];
                for(var nr2=0; nr2<result.length; nr2++) {
                    if(result[nr2].val == val) {
                        return([result[nr2]]);
                    }
                }
            }
        }
        // nothing matched, use first
        local_perf_bar_mode = 'first';
    }
    if(local_perf_bar_mode == 'first') {
        return([result[0]]);
    }
    return result;
}

/* try to get only a specific key form our result */
function perf_get_graph_from_result(key, result) {
    for(var nr=0; nr<result.length; nr++) {
        if(result[nr].field == key) {
            return([result[nr]]);
        }
    }
    return(result);
}

/* try to make a smaller number */
function perf_reduce(value, unit) {
    if(value < 1000) { return(''+perf_round(value)+unit); }
    if(value > 1500 && unit == 'B') {
        value = value / 1000;
        unit  = 'KB';
    }
    if(value > 1500 && unit == 'KB') {
        value = value / 1000;
        unit  = 'MB';
    }
    if(value > 1500 && unit == 'MB') {
        value = value / 1000;
        unit  = 'GB';
    }
    if(value > 1500 && unit == 'GB') {
        value = value / 1000;
        unit  = 'TB';
    }
    if(value > 1500 && unit == 'ms') {
        value = value / 1000;
        unit  = 's';
    }
    return(''+perf_round(value)+unit);
}

/* round value to human readable */
function perf_round(value) {
    if((value - parseInt(value)) == 0) { return(value); }
    if(value >= 100) { return(value.toFixed(0)); }
    if(value < 100)  { return(value.toFixed(1)); }
    if(value <  10)  { return(value.toFixed(2)); }
    return(value);
}

/*******************************************************************************
  ,ad8888ba,  88b           d88 88888888ba,
 d8"'    `"8b 888b         d888 88      `"8b
d8'           88`8b       d8'88 88        `8b
88            88 `8b     d8' 88 88         88
88            88  `8b   d8'  88 88         88
Y8,           88   `8b d8'   88 88         8P
 Y8a.    .a8P 88    `888'    88 88      .a8P
  `"Y8888Y"'  88     `8'     88 88888888Y"'

 Mouse Over for Status Table
 to select hosts / services
 for sending quick commands
*******************************************************************************/
var selectedServices = new Object();
var selectedHosts    = new Object();
var noEventsForId    = new Object();
var submit_form_id;
var pagetype         = undefined;

/* add mouseover eventhandler for all cells and execute it once */
function addRowSelector(id, type) {
    var row   = document.getElementById(id);
    var cells = row.cells;

    // remove this eventhandler, it has to fire only once
    if(noEventsForId[id]) {
        return false;
    }
    if( row.detachEvent ) {
        noEventsForId[id] = 1;
    } else {
        row.onmouseover = undefined;
    }

    // reset all current highlighted rows
    reset_all_hosts_and_services();

    if(type == 'host') {
      pagetype = 'hostdetail'
    }
    else if(type == 'service') {
      pagetype = 'servicedetail'
    } else {
      if(thruk_debug_js) { alert("ERROR: unknown table addRowSelector(): " + typ); }
    }

    // for each cell in a row
    var is_host = false;
    for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
        if(pagetype == "hostdetail" || (cell_nr == 0 && cells[0].innerHTML != '')) {
            is_host = true;
            if(pagetype == 'hostdetail') {
                addEvent(cells[cell_nr], 'mouseover', set_pagetype_hostdetail);
            } else {
                addEvent(cells[cell_nr], 'mouseover', set_pagetype_servicedetail);
            }
            addEventHandler(cells[cell_nr], 'host');
        }
        else if(cell_nr >= 1) {
            is_host = false;
            addEvent(cells[cell_nr], 'mouseover', set_pagetype_servicedetail);
            addEventHandler(cells[cell_nr], 'service');
        }
    }

    // initial mouseover highlights host&service, reset class here
    if(pagetype == "servicedetail") {
        reset_all_hosts_and_services(true, false);
    }

    if(is_host) {
        //addEvent(row, 'mouseout', resetHostRow);
        appendRowStyle(id, 'tableRowHover', 'host');
    } else {
        //addEvent(row, 'mouseout', resetServiceRow);
        appendRowStyle(id, 'tableRowHover', 'service');
    }
    return true;
}

/* reset all current hosts and service rows */
function reset_all_hosts_and_services(hosts, services) {
    var rows = Array();
    jQuery('td.tableRowHover').each(function(i, el) {
        rows.push(el.parentNode);
    });

    jQuery.unique(rows);
    jQuery(rows).each(function(i, el) {
        resetHostRow(el);
        resetServiceRow(el);
    });
}

/* set right pagetype */
function set_pagetype_hostdetail() {
    pagetype = "hostdetail";
}
function set_pagetype_servicedetail() {
    pagetype = "servicedetail";
}

/* add the event handler */
function addEventHandler(elem, type) {
    if(type == 'host') {
        addEvent(elem, 'mouseover', highlightHostRow);
        if(!elem.onclick) {
            elem.onclick = selectHost;
        }
    }
    if(type == 'service') {
        addEvent(elem, 'mouseover', highlightServiceRow);
        if(!elem.onclick) {
            elem.onclick = selectService;
        }
    }
}

/* add additional eventhandler to object */
function addEvent( obj, type, fn ) {
  //debug("addEvent("+obj+","+type+", ...)");
  if ( obj.attachEvent ) {
    obj['e'+type+fn] = fn;
    obj[type+fn] = function(){obj['e'+type+fn]( window.event );}
    obj.attachEvent( 'on'+type, obj[type+fn] );
  } else
    obj.addEventListener( type, fn, false );
}

/* remove an eventhandler from object */
function removeEvent( obj, type, fn ) {
  //debug("removeEvent("+obj+","+type+", ...)");
  if ( obj.detachEvent ) {
    obj.detachEvent( 'on'+type, obj[type+fn] );
    obj[type+fn] = null;
  } else
    obj.removeEventListener( type, fn, false );
}


/* returns the first element which has an id */
function getFirstParentId(elem) {
    if(!elem) {
        if(thruk_debug_js) { alert("ERROR: got no element in getFirstParentId()"); }
        return false;
    }
    nr = 0;
    while(nr < 10 && !elem.id) {
        nr++;
        if(!elem.parentNode) {
            // this may happen when looking for the parent of a event
            return false;
        }
        elem = elem.parentNode;
    }
    return elem.id;
}

/* set style for each cell */
function setRowStyle(row_id, style, type, force) {

    var row = document.getElementById(row_id);
    if(!row) {
        if(thruk_debug_js) { alert("ERROR: got no row in setRowStyle(): " + row_id); }
        return false;
    }

    // for each cells in this row
    var cells = row.cells;
    if(!cells) {
        return false;
    }
    for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
        // only the first cell for hosts
        // all except the first cell for services
        if((type == 'host' && pagetype == 'hostdetail') || (type == 'host' && cell_nr == 0) || (type == 'service' && cell_nr >= 1)) {
            // set style for cell itself
            styleElements(cells[cell_nr], style, force)

            // and for all row elements below
            var elems = cells[cell_nr].getElementsByTagName('TR');
            styleElements(elems, style, force)

            // and for all cell elements below
            var elems = cells[cell_nr].getElementsByTagName('TD');
            styleElements(elems, style, force)
        }
    }
    return true;
}

/* set style for each cell */
function appendRowStyle(row_id, style, type, recursive) {
    var row = document.getElementById(row_id);
    if(!row) {
        if(thruk_debug_js) { alert("ERROR: got no row in appendRowStyle(): " + row_id); }
        return false;
    }
    // for each cells in this row
    var cells = row.cells;
    if(!cells) {
        return false;
    }
    if(recursive == undefined) { recursive = false; }
    for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
        // only the first cell for hosts
        // all except the first cell for services
        if((type == 'host' && pagetype == 'hostdetail') || (type == 'host' && cell_nr == 0) || (type == 'service' && cell_nr >= 1)) {
            // set style for cell itself
            addStyle(cells[cell_nr], style)

            if(recursive) {
                // and for all row elements below
                var elems = cells[cell_nr].getElementsByTagName('TR');
                addStyle(elems, style)

                // and for all cell elements below
                var elems = cells[cell_nr].getElementsByTagName('TD');
                addStyle(elems, style)
            }
        }
    }
    return true;
}

/* remove style for each cell */
function removeRowStyle(row_id, styles, type) {

    var row = document.getElementById(row_id);
    if(!row) {
        if(thruk_debug_js) { alert("ERROR: got no row in appendRowStyle(): " + row_id); }
        return false;
    }
    // for each cells in this row
    var cells = row.cells;
    if(!cells) {
        return false;
    }
    for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
        // only the first cell for hosts
        // all except the first cell for services
        if((type == 'host' && pagetype == 'hostdetail') || (type == 'host' && cell_nr == 0) || (type == 'service' && cell_nr >= 1)) {
            // set style for cell itself
            removeStyle(cells[cell_nr], styles)

            // and for all row elements below
            var elems = cells[cell_nr].getElementsByTagName('TR');
            removeStyle(elems, styles)

            // and for all cell elements below
            var elems = cells[cell_nr].getElementsByTagName('TD');
            removeStyle(elems, styles)
        }
    }
    return true;
}

/* add style to given element(s) */
function addStyle(elems, style) {
    if (elems == null || ( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
        elems = new Array(elems);
    }
    jQuery.each(elems, function(nr, el) {
        jQuery(el).addClass(style);
    });
    return;
}

/* remove style to given element(s) */
function removeStyle(elems, styles) {
    if (elems == null || ( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
        elems = new Array(elems);
    }
    jQuery.each(elems, function(nr, el) {
        jQuery.each(styles, function(nr, s) {
            jQuery(el).removeClass(s);
        });
    });
    return;
}

/* save current style and change it*/
function styleElements(elems, style, force) {
    if (elems == null ) {
        return;
    }
    if (( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
        elems = new Array(elems);
    }

    if(navigator.appName == "Microsoft Internet Explorer") {
        return styleElementsIE(elems, style, force);
    }
    else {
        return styleElementsFF(elems, style, force);
    }
}

/* save current style and change it (IE only) */
function styleElementsIE(elems, style, force) {
    for(var x = 0; x < elems.length; x++) {
        if(style == 'original') {
            // reset style to original
            if(elems[x].className != "tableRowSelected" || force) {
                if(elems[x].origclass != undefined) {
                    elems[x].className = elems[x].origclass;
                }
            }
        }
        else {
            if(elems[x].className != "tableRowSelected" || force) {
                // save style in custom attribute
                if(elems[x].className != undefined && elems[x].className != "tableRowSelected" && elems[x].className != "tableRowHover") {
                    elems[x].setAttribute('origclass', elems[x].className);
                }

                // set new style
                elems[x].className = style;
            }
        }
    }
}

/* save current style and change it (non IE version) */
function styleElementsFF(elems, style, force) {
    for(var x = 0; x < elems.length; x++) {
        if(style == 'original') {
            // reset style to original
            if(elems[x].hasAttribute('origClass') && (elems[x].className == "tableRowHover" || force)) {
                elems[x].className = elems[x].origClass;
            }
        }
        else {
            if(elems[x].className != "tableRowSelected" || force) {
                // save style in custom attribute
                if(!elems[x].hasAttribute('origClass')) {
                    elems[x].setAttribute('origClass', elems[x].className);
                    elems[x].origClass = elems[x].className;
                }

                // set new style
                elems[x].className = style;
            }
        }
    }
}

/* this is the mouseover function for services */
function highlightServiceRow() {
    // find id of current row
    var row_id = getFirstParentId(this);
    if(!row_id) {
      return;
    }

    // reset all current highlighted rows
    reset_all_hosts_and_services();

    lastRowHighlighted = row_id;
    appendRowStyle(row_id, 'tableRowHover', 'service');
}

/* this is the mouseover function for hosts */
function highlightHostRow() {
    // find id of current row
    var row_id = getFirstParentId(this);
    if(!row_id) {
      return;
    }

    // reset all current highlighted rows
    reset_all_hosts_and_services();

    lastRowHighlighted = row_id;
    appendRowStyle(row_id, 'tableRowHover', 'host');
}

/* select this service */
function selectService(event, state) {
    var t = getTextSelection();
    var l = t.split(/\r?\n|\r/).length;
    if(t != '' && l == 1) {
        /* make text selections easier */
        return;
    }

    unselectCurrentSelection();
    var row_id;
    // find id of current row
    if(event && event.target) {
        /* ex.: FF */
        row_id = getFirstParentId(event.target);

        // dont select row when clicked on a link
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG') {
            resetServiceRow(event);
            return;
        }
    }
    else if (event && (event.id || event.parentNode)) {
        row_id = getFirstParentId(event);
    }
    else {
        /* ex.: IE 7/8 */
        if(window.event.srcElement.tagName == 'A' || window.event.srcElement.tagName == 'IMG') {
            resetServiceRow(event);
            return;
        }
        row_id = getFirstParentId(this);
        event  = this;
    }
    if(!row_id) {
        return;
    }

    selectServiceByIdEvent(row_id, state, event);
    unselectCurrentSelection();
}

/* select this service */
function selectServiceByIdEvent(row_id, state, event) {
    row_id = row_id.replace(/_s_exec$/, '');

    if(is_shift_pressed(event) && lastRowSelected != undefined) {
      no_more_events = 1;
      var id1         = parseInt(row_id.substring(5));
      var id2         = parseInt(lastRowSelected.substring(5));
      var pane_prefix = row_id.substring(0,4);

      // all selected should get the same state
      state = false;
      if(selectedServices[lastRowSelected]) {
        state = true;
      }

      // selected top down?
      if(id1 > id2) {
        var tmp = id2;
        id2 = id1;
        id1 = tmp;
      }

      for(var x = id1; x < id2; x++) {
        selectServiceByIdEvent(pane_prefix+'r'+x, state);
      }
      lastRowSelected = undefined;
      no_more_events  = 0;
    }
    else {
      lastRowSelected = row_id;
    }

    selectServiceById(row_id, state);

    checkCmdPaneVisibility();
}

/* select service row by id */
function selectServiceById(row_id, state) {
    row_id = row_id.replace(/_s_exec$/, '');
    var targetState;
    if(state != undefined) {
        targetState = state;
    }
    else if(selectedServices[row_id]) {
        targetState = false;
    }
    else {
        targetState = true;
    }

    // dont select the empty cells in services view
    row = document.getElementById(row_id);
    if(!row) {
        return false;
    }

    if(targetState) {
        appendRowStyle(row_id, 'tableRowSelected', 'service', true);
        selectedServices[row_id] = 1;
    } else {
        removeRowStyle(row_id, ['tableRowSelected', 'tableRowHover'], 'service');
        delete selectedServices[row_id];
    }
    return true;
}

/* select this host */
function selectHost(event, state) {
    var t = getTextSelection();
    var l = t.split(/\r?\n|\r/).length;
    if(t != '' && l == 1) {
        /* make text selections easier */
        return;
    }
    unselectCurrentSelection();

    var row_id;
    // find id of current row
    if(event && event.target) {
        /* ex.: FF */
        row_id = getFirstParentId(event.target);

        // dont select row when clicked on a link
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG') {
            resetHostRow(event);
            return;
        }
    }
    else if (event && (event.id || event.parentNode)) {
        row_id = getFirstParentId(event);
    }
    else {
        /* ex.: IE 7/8 */
        if(window.event.srcElement.tagName == 'A' || window.event.srcElement.tagName == 'IMG') {
            resetHostRow(event);
            return;
        }
        row_id = getFirstParentId(this);
        event  = this;
    }
    if(!row_id) {
        return;
    }

    selectHostByIdEvent(row_id, state, event);
    unselectCurrentSelection();
}


/* select this service */
function selectHostByIdEvent(row_id, state, event) {
    row_id = row_id.replace(/_h_exec$/, '');

    if(is_shift_pressed(event) && lastRowSelected != undefined) {
      no_more_events = 1;
      var id1         = parseInt(row_id.substring(5));
      var id2         = parseInt(lastRowSelected.substring(5));
      var pane_prefix = row_id.substring(0,4);

      // all selected should get the same state
      state = false;
      if(selectedHosts[lastRowSelected]) {
        state = true;
      }

      // selected top down?
      if(id1 > id2) {
        var tmp = id2;
        id2 = id1;
        id1 = tmp;
      }

      for(var x = id1; x < id2; x++) {
        selectHostByIdEvent(pane_prefix+'r'+x, state);
      }
      lastRowSelected = undefined;
      no_more_events  = 0;
    } else {
      lastRowSelected = row_id;
    }

    selectHostById(row_id, state);

    checkCmdPaneVisibility();
}

/* set host row selected */
function selectHostById(row_id, state) {
    row_id = row_id.replace(/_h_exec$/, '');
    var targetState;
    if(state != undefined) {
        targetState = state;
    }
    else if(selectedHosts[row_id]) {
        targetState = false;
    }
    else {
        targetState = true;
    }

    // dont select the empty cells in services view
    row = document.getElementById(row_id);
    if(!row || !row.cells || row.cells.length == 0) {
      return false;
    }
    if(row.cells[0].innerHTML == "") {
      return true;
    }

    if(targetState) {
        appendRowStyle(row_id, 'tableRowSelected', 'host', true);
        selectedHosts[row_id] = 1;
    } else {
        removeRowStyle(row_id, ['tableRowSelected', 'tableRowHover'], 'host');
        delete selectedHosts[row_id];
    }
    return true;
}


/* reset row style unless it has been clicked */
function resetServiceRow(event) {
    var row_id;
    if(!event) {
        event = this;
    }
    // find id of current row
    if(event.target) {
        row_id = getFirstParentId(event.target);
    } else {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        if(lastRowHighlighted) {
            tmp = lastRowHighlighted;
            lastRowHighlighted = undefined;
            setRowStyle(tmp, 'original', 'service');
        }
        return;
    }
    removeRowStyle(row_id, ['tableRowHover'], 'service');
}

/* reset row style unless it has been clicked */
function resetHostRow(event) {
    var row_id;
    if(!event) {
        event = this;
    }
    // find id of current row
    if(event.target) {
        row_id = getFirstParentId(event.target);
    } else {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        if(lastRowHighlighted) {
            tmp = lastRowHighlighted;
            lastRowHighlighted = undefined;
            setRowStyle(tmp, 'original', 'host');
        }
        return;
    }
    removeRowStyle(row_id, ['tableRowHover'], 'host');
}

/* select or deselect all services */
function selectAllServices(state, pane_prefix) {
    var x = 0;
    while(selectServiceById(pane_prefix+'r'+x, state)) {
        // disable next row
        x++;
    };

    checkCmdPaneVisibility();
}
/* select services by class name */
function selectServicesByClass(classes) {
    jQuery.each(classes, function(i, classname) {
        jQuery(classname).each(function(i, obj) {
            selectService(obj, true);
        })
    });
    return false;
}

/* select hosts by class name */
function selectHostsByClass(classes) {
    jQuery.each(classes, function(i, classname) {
        jQuery(classname).each(function(i, obj) {
            selectHost(obj, true);
        })
    });
    return false;
}

/* select or deselect all hosts */
function selectAllHosts(state, pane_prefix) {
    var x = 0;
    while(selectHostById(pane_prefix+'r'+x, state)) {
        // disable next row
        x++;
    };

    checkCmdPaneVisibility();
}

/* toggle the visibility of the command pane */
function toggleCmdPane(state) {
  if(state == 1) {
    showElement('cmd_pane');
    cmdPaneState = 1;
  }
  else {
    hideElement('cmd_pane');
    cmdPaneState = 0;
  }
}

/* show command panel if there are services or hosts selected otherwise hide the panel */
function checkCmdPaneVisibility() {
    var ssize = keys(selectedServices).length;
    var hsize = keys(selectedHosts).length;
    var size  = ssize + hsize;
    if(size == 0) {
        /* hide command panel */
        toggleCmdPane(0);
    } else {
        resetRefresh();

        /* set submit button text */
        var btn = document.getElementById('multi_cmd_submit_button');
        var serviceName = "services";
        if(ssize == 1) { serviceName = "service";  }
        var hostName = "hosts";
        if(hsize == 1) { hostName = "host";  }
        var text;
        if( hsize > 0 && ssize > 0 ) {
            text = ssize + " " + serviceName + " and " + hsize + " " + hostName;
        }
        else if( hsize > 0 ) {
            text = hsize + " " + hostName;
        }
        else if( ssize > 0 ) {
            text = ssize + " " + serviceName;
        }
        btn.value = "submit command for " + text;
        check_selected_command();

        /* show command panel */
        toggleCmdPane(1);
    }
}

/* collect selected hosts and services and pack them into nice form data */
function collectFormData(form_id) {

    if(verification_errors != undefined && keys(verification_errors).length > 0) {
        alert('please enter valid data');
        return(false);
    }

    // set activity icon
    check_quick_command();

    // check form values
    var sel = document.getElementById('quick_command');
    var value = sel.value;
    if(value == 2 || value == 3 || value == 4) { /* add downtime / comment / acknowledge */
        if(document.getElementById('com_data').value == '') {
            alert('please enter a comment');
            return(false);
        }
    }

    if(value == 12) { /* submit passive result */
        if(document.getElementById('plugin_output').value == '') {
            alert('please enter a check result');
            return(false);
        }
    }

    ids_form = document.getElementById('selected_ids');
    if(ids_form) {
        // comments / downtime commands
        ids_form.value = keys(selectedHosts).join(',');
    }
    else {
        // regular services commands
        var services = new Array();
        jQuery.each(selectedServices, function(row_id, blah) {
            if(row_id.substr(0,4) == "hst_") { obj_hash = hst_Hash; }
            if(row_id.substr(0,4) == "svc_") { obj_hash = svc_Hash; }
            if(row_id.substr(0,4) == "dfl_") { obj_hash = dfl_Hash; }
            row_id = row_id.substr(4);
            services.push(obj_hash[row_id]);
        });
        service_form = document.getElementById('selected_services');
        service_form.value = services.join(',');

        var hosts = new Array();
        jQuery.each(selectedHosts, function(row_id, blah) {
            if(row_id.substr(0,4) == "hst_") { obj_hash = hst_Hash; }
            if(row_id.substr(0,4) == "svc_") { obj_hash = svc_Hash; }
            if(row_id.substr(0,4) == "dfl_") { obj_hash = dfl_Hash; }
            row_id = row_id.substr(4);
            hosts.push(obj_hash[row_id]);
        });
        host_form = document.getElementById('selected_hosts');
        host_form.value = hosts.join(',');
    }

    // save scroll position to referer
    var form_ref = document.getElementById('form_cmd_referer');
    if(form_ref) {
        form_ref.value += '&scrollTo=' + getPageScroll();
    }

    if(value == 1 ) { // reschedule
        var btn = document.getElementById(form_id);
        if(btn) {
            submit_form_id = form_id;
            window.setTimeout(submit_form, 100);
            return(false);
        }
    }

    return(true);
}

/* return scroll position */
function getPageScroll() {
    var yScroll;
    if (self.pageYOffset) {
        yScroll = self.pageYOffset;
    } else if (document.documentElement && document.documentElement.scrollTop) {
        yScroll = document.documentElement.scrollTop;
    } else if (document.body) {
        yScroll = document.body.scrollTop;
    }
    return Number(yScroll).toFixed(0);
}

/* submit a form by id */
function submit_form() {
    var btn = document.getElementById(submit_form_id);
    btn.submit();
}

/* show/hide options for commands based on the selected command*/
function check_selected_command() {
    var sel = document.getElementById('quick_command');
    var value = sel.value;

    disableAllFormElement();
    if(value == 1) { /* reschedule next check */
        enableFormElement('row_start');
        enableFormElement('row_reschedule_options');
    }
    if(value == 2) { /* add downtime */
        enableFormElement('row_start');
        enableFormElement('row_end');
        enableFormElement('row_comment');
        enableFormElement('row_downtime_options');
    }
    if(value == 3) { /* add comment */
        enableFormElement('row_comment');
        enableFormElement('row_comment_options');
        document.getElementById('opt_persistent').value = 'comments';
    }
    if(value == 4) { /* add acknowledgement */
        enableFormElement('row_comment');
        enableFormElement('row_ack_options');
        document.getElementById('opt_persistent').value = 'ack';
        if(has_expire_acks) {
            enableFormElement('opt_expire');
            if(document.getElementById('opt5').checked == true) {
                enableFormElement('row_expire');
            }
        }
    }
    if(value == 5) { /* remove downtimes */
        enableFormElement('row_down_options');
    }
    if(value == 6) { /* remove comments */
    }
    if(value == 7) { /* remove acknowledgement */
    }
    if(value == 8) { /* enable active checks */
    }
    if(value == 9) { /* disable active checks */
        enableFormElement('row_comment_disable_cmd');
    }
    if(value == 10) { /* enable notifications */
    }
    if(value == 11) { /* disable notifications */
        enableFormElement('row_comment_disable_cmd');
    }
    if(value == 12) { /* submit passive check result */
        enableFormElement('row_submit_options');
    }
}

/* hide all form element rows */
function disableAllFormElement() {
    var elems = new Array('row_start', 'row_end', 'row_comment', 'row_comment_disable_cmd', 'row_downtime_options', 'row_reschedule_options', 'row_ack_options', 'row_comment_options', 'row_submit_options', 'row_expire', 'opt_expire', 'row_down_options');
    jQuery.each(elems, function(index, id) {
        obj = document.getElementById(id);
        obj.style.display = "none";
    });
}

/* show this form row */
function enableFormElement(id) {
    obj = document.getElementById(id);
    obj.style.display = "";
}


/* verify submited command */
function check_quick_command() {
    var sel   = document.getElementById('quick_command');
    var value = sel.value;
    var img;

    // disable hide timer
    window.clearTimeout(hide_activity_icons_timer);

    if(value == 1 ) { // reschedule
        jQuery.each(selectedServices, function(row_id, blah) {
            var cell = document.getElementById(row_id + "_s_exec");
            if(cell) {
                cell.innerHTML = '';
                img            = document.createElement('img');
                img.src        = url_prefix + 'themes/' + theme + '/images/waiting.gif';
                img.height     = 20;
                img.width      = 20;
                img.title      = "This service is currently executing its servicecheck";
                img.alt        = "This service is currently executing its servicecheck";
                cell.appendChild(img);
            }
        });
        jQuery.each(selectedHosts, function(row_id, blah) {
            var cell = document.getElementById(row_id + "_h_exec");
            if(cell) {
                cell.innerHTML = '';
                img            = document.createElement('img');
                img.src        = url_prefix + 'themes/' + theme + '/images/waiting.gif';
                img.height     = 20;
                img.width      = 20;
                img.title      = "This host is currently executing its hostcheck";
                img.alt        = "This host is currently executing its hostcheck";
                cell.appendChild(img);
            }
        });
        var btn = document.getElementById('multi_cmd_submit_button');
        btn.value = "processing commands...";
    }

    return true;
}


/* select this service */
function toggle_comment(event) {
    var t = getTextSelection();
    var l = t.split(/\r?\n|\r/).length;
    if(t != '' && l == 1) {
        /* make text selections easier */
        return false;
    }

    if(!event) {
        event = this;
    }
    if(event && event.target) {
        // dont select row when clicked on a link
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG') {
            return true;
        }
    }

    // find id of current row
    if(event.target) {
        row_id = getFirstParentId(event.target);
    } else {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        return false;
    }

    var state = true;
    if(selectedHosts[row_id]) {
        state = false;
    }

    if(is_shift_pressed(event) && lastRowSelected != undefined) {
        no_more_events = 1;

        // all selected should get the same state
        state = false;
        if(selectedHosts[lastRowSelected]) {
            state = true;
        }

        var inside = false;
        jQuery("TR.clickable").each(function(nr, elem) {
          if(! jQuery(elem).is(":visible")) {
            return true;
          }
          if(inside == true) {
            if(elem.id == lastRowSelected || elem.id == row_id) {
                return false;
            }
          }
          else {
            if(elem.id == lastRowSelected || elem.id == row_id) {
              inside = true;
            }
          }
          if(inside == true) {
            selectCommentById(elem.id, state);
          }
          return true;
        });

        // selectCommentById(pane_prefix+x, state);

        lastRowSelected = undefined;
        no_more_events  = 0;
    } else {
        lastRowSelected = row_id;
    }

    selectCommentById(row_id, state);

    // check visibility of command pane
    var number = keys(selectedHosts).length;
    var text = "remove " + number + " " + type;
    if(number != 1) {
        text = text + "s";
    }
    jQuery('#quick_command')[0].options[0].text = text;
    if(number > 0) {
        showElement('cmd_pane');
    } else {
        hideElement('cmd_pane');
    }

    unselectCurrentSelection();

    return false;
}

/* toggle selection of comment on downtimes/comments page */
function selectCommentById(row_id, state) {
    var row   = document.getElementById(row_id);
    if(!row) {
        if(thruk_debug_js) { alert("ERROR: unknown id in selectCommentById(): " + row_id); }
        return false;
    }
    var elems = row.getElementsByTagName('TD');

    if(state == false) {
        delete selectedHosts[row_id];
        styleElements(elems, "original", 1);
    } else {
        selectedHosts[row_id] = row_id;
        styleElements(elems, 'tableRowSelected', 1)
    }
    return false;
}

/* unselect all selections on downtimes/comments page */
function unset_comments() {
    jQuery.each(selectedHosts, function(nr, blah) {
        var row_id = selectedHosts[nr];
        var row    = document.getElementById(row_id);
        var elems  = row.getElementsByTagName('TD');
        styleElements(elems, "original", 1);
        delete selectedHosts[nr];
    });
    hideElement('cmd_pane');
}

/*******************************************************************************
88888888888  88   88     888888888888 88888888888 88888888ba
88           88   88          88      88          88      "8b
88           88   88          88      88          88      ,8P
88aaaaa      88   88          88      88aaaaa     88aaaaaa8P'
88"""""      88   88          88      88"""""     88""""88'
88           88   88          88      88          88    `8b
88           88   88          88      88          88     `8b
88           88   88888888888 88      88888888888 88      `8b

everything needed for displaying and changing filter
on status / host details page
*******************************************************************************/

/* toggle the visibility of the filter pane */
function toggleFilterPane(prefix) {
  //debug("toggleFilterPane(): " + toggleFilterPane.caller);
  var pane = document.getElementById(prefix+'all_filter_table');
  var img  = document.getElementById(prefix+'filter_button');
  if(pane.style.display == 'none') {
    showElement(prefix+'all_filter_table');
    img.style.display     = 'none';
    img.style.visibility  = 'hidden';
  }
  else {
    hideElement(prefix+'all_filter_table');
    img.style.display     = '';
    img.style.visibility  = 'visible';
  }
}

/* toggle filter pane */
function toggleFilterPaneSelector(search_prefix, id) {
  var panel;
  var checkbox_name;
  var input_name;
  var checkbox_prefix;

  search_prefix = search_prefix.substring(0, 7);

  if(id == "hoststatustypes") {
    panel           = 'hoststatustypes_pane';
    checkbox_name   = 'hoststatustype';
    input_name      = 'hoststatustypes';
    checkbox_prefix = 'ht';
  }
  if(id == "hostprops") {
    panel           = 'hostprops_pane';
    checkbox_name   = 'hostprop';
    input_name      = 'hostprops';
    checkbox_prefix = 'hp';
  }
  if(id == "servicestatustypes") {
    panel           = 'servicestatustypes_pane';
    checkbox_name   = 'servicestatustype';
    input_name      = 'servicestatustypes';
    checkbox_prefix = 'st';
  }
  if(id == "serviceprops") {
    panel           = 'serviceprops_pane';
    checkbox_name   = 'serviceprop';
    input_name      = 'serviceprops';
    checkbox_prefix = 'sp';
  }

  if(!panel) {
    if(thruk_debug_js) { alert("ERROR: unknown id in toggleFilterPaneSelector(): " + search_prefix + id); }
    return;
  }
  var accept_callback = function() { accept_filter_types(search_prefix, checkbox_name, input_name, checkbox_prefix)};
  if(!toggleElement(search_prefix+panel, undefined, true, undefined, accept_callback)) {
    accept_callback();
    remove_close_element(search_prefix+panel);
  } {
    set_filter_types(search_prefix, input_name, checkbox_prefix);
  }
}

/* calculate the sum for a filter */
function accept_filter_types(search_prefix, checkbox_names, result_name, checkbox_prefix) {
    var inp  = document.getElementsByName(search_prefix + result_name);
    if(!inp || inp.length == 0) {
      if(thruk_debug_js) { alert("ERROR: no element in accept_filter_types() for: " + search_prefix + result_name); }
      return;
    }
    var orig = inp[0].value;
    var sum = 0;
    jQuery("input[name="+search_prefix + checkbox_names+"]").each(function(index, elem) {
        if(elem.checked) {
            sum += parseInt(elem.value);
        }
    });
    inp[0].value = sum;

    set_filter_name(search_prefix, checkbox_names, checkbox_prefix, parseInt(sum));
}

/* set the initial state of filter checkboxes */
function set_filter_types(search_prefix, initial_id, checkbox_prefix) {
    var inp = document.getElementsByName(search_prefix + initial_id);
    if(!inp || inp.length == 0) {
      if(thruk_debug_js) { alert("ERROR: no element in set_filter_types() for: " + search_prefix + initial_id); }
      return;
    }
    var initial_value = parseInt(inp[0].value);
    var bin  = initial_value.toString(2);
    var bits = new Array(); bits = bin.split('').reverse();
    for (var index = 0, len = bits.length; index < len; ++index) {
        var bit = bits[index];
        var nr  = Math.pow(2, index);
        var checkbox = document.getElementById(search_prefix + checkbox_prefix + nr);
        if(!checkbox) {
          if(thruk_debug_js) { alert("ERROR: got no checkbox for id in set_filter_types(): " + search_prefix + checkbox_prefix + nr); }
          return;
        }
        if(bit == '1') {
            checkbox.checked = true;
        } else {
            checkbox.checked = false;
        }
    }
}

/* set the filtername */
function set_filter_name(search_prefix, checkbox_names, checkbox_prefix, filtervalue) {
  var order;
  if(checkbox_prefix == 'ht') {
    order = hoststatustypes;
  }
  else if(checkbox_prefix == 'hp') {
    order = hostprops;
  }
  else if(checkbox_prefix == 'st') {
    order = servicestatustypes;
  }
  else if(checkbox_prefix == 'sp') {
    order = serviceprops;
  }
  else {
    if(thruk_debug_js) { alert('ERROR: unknown prefix in set_filter_name(): ' + checkbox_prefix); }
  }

  var checked_ones = new Array();
  jQuery.each(order, function(index, bit) {
    checkbox = document.getElementById(search_prefix + checkbox_prefix + bit);
    if(!checkbox) {
        if(thruk_debug_js) { alert('ERROR: got no checkbox in set_filter_name(): ' + search_prefix + checkbox_prefix + bit); }
    }
    if(checkbox.checked) {
      nameElem = document.getElementById(search_prefix + checkbox_prefix + bit + 'n');
      if(!nameElem) {
        if(thruk_debug_js) { alert('ERROR: got no element in set_filter_name(): ' + search_prefix + checkbox_prefix + bit + 'n'); }
      }
      checked_ones.push(nameElem.innerHTML);
    }
  });

  /* some override names */
  if(checkbox_prefix == 'ht') {
    filtername = checked_ones.join(' | ');
    if(filtervalue == 0 || filtervalue == 15) {
      filtername = 'All';
    }
    if(filtervalue == 12) {
      filtername = 'All problems';
    }
  }

  if(checkbox_prefix == 'st') {
    filtername = checked_ones.join(' | ');
    if(filtervalue == 0 || filtervalue == 31) {
      filtername = 'All';
    }
    if(filtervalue == 28) {
      filtername = 'All problems';
    }
  }

  if(checkbox_prefix == 'hp') {
    filtername = checked_ones.join(' & ');
    if(filtervalue == 0) {
      filtername = 'Any';
    }
  }

  if(checkbox_prefix == 'sp') {
    filtername = checked_ones.join(' & ');
    if(filtervalue == 0) {
      filtername = 'Any';
    }
  }

  target = document.getElementById(search_prefix + checkbox_prefix + 'n');
  target.innerHTML = filtername;
}

function getFilterTypeOptions() {
    var important = new Array(/* when changed, update _status_filter.tt too! */
        'Search',
        'Host',
        'Service',
        'Hostgroup',
        'Servicegroup',
        '----------------'
    );
    var others = new Array(
        'Check Period',
        'Comment',
        'Contact',
        'Current Attempt',
        'Custom Variable',
        'Downtime Duration',
        'Duration',
        'Event Handler',
        'Execution Time',
        'Last Check',
        'Latency',
        'Next Check',
        'Notification Period',
        'Number of Services',
        'Parent',
        'Plugin Output',
        '% State Change'
       );
    if(enable_shinken_features) {
        others.unshift('Business Impact');
    }
    var options = Array();
    options = options.concat(important);
    options = options.concat(others.sort());
    return(options);
}

/* add a new filter selector to this table */
function add_new_filter(search_prefix, table) {
  pane_prefix   = search_prefix.substring(0,4);
  search_prefix = search_prefix.substring(4);
  var index     = search_prefix.indexOf('_');
  search_prefix = search_prefix.substring(0,index+1);
  table         = table.substring(4);
  tbl           = document.getElementById(pane_prefix+search_prefix+table);
  if(!tbl) {
    if(thruk_debug_js) { alert("ERROR: got no table for id in add_new_filter(): " + pane_prefix+search_prefix+table); }
    return;
  }

  // add new row
  var tblBody        = tbl.tBodies[0];
  var currentLastRow = tblBody.rows.length - 1;
  var newRow         = tblBody.insertRow(currentLastRow);

  // get first free number of typeselects
  var nr = 0;
  for(var x = 0; x<= 99; x++) {
    tst = document.getElementById(pane_prefix + search_prefix + x + '_ts');
    if(tst) { nr = x+1; }
  }

  // add first cell
  var typeselect = document.createElement('select');
  var options    = getFilterTypeOptions();

  typeselect.onchange   = verify_op;
  typeselect.setAttribute('name', pane_prefix + search_prefix + 'type');
  typeselect.setAttribute('id', pane_prefix + search_prefix + nr + '_ts');
  add_options(typeselect, options);

  var opselect          = document.createElement('select');
  var options           = new Array('~', '!~', '=', '!=', '<=', '>=');
  opselect.setAttribute('name', pane_prefix + search_prefix + 'op');
  opselect.setAttribute('id', pane_prefix + search_prefix + nr + '_to');
  opselect.className='filter_op_select';
  add_options(opselect, options);

  var newCell0 = newRow.insertCell(0);
  newCell0.nowrap    = "true";
  newCell0.className = "filterValueInput";
  newCell0.colSpan   = 2;
  newCell0.appendChild(typeselect);

  var newInputPre    = document.createElement('input');
  newInputPre.type      = 'text';
  newInputPre.value     = '';
  newInputPre.className = 'filter_pre_value';
  newInputPre.setAttribute('name', pane_prefix + search_prefix + 'val_pre');
  newInputPre.setAttribute('id',   pane_prefix + search_prefix + nr + '_val_pre');
  newInputPre.style.display    = "none";
  newInputPre.style.visibility = "hidden";
  if(ajax_search_enabled) {
    newInputPre.onclick = function() { ajax_search.init(this, 'custom variable') };
  }
  newCell0.appendChild(newInputPre);

  newCell0.appendChild(opselect);

  var newInput       = document.createElement('input');
  newInput.type      = 'text';
  newInput.value     = '';
  newInput.setAttribute('name', pane_prefix + search_prefix + 'value');
  newInput.setAttribute('id',   pane_prefix + search_prefix + nr + '_value');
  if(ajax_search_enabled) {
    newInput.onclick = ajax_search.init;
  }
  newCell0.appendChild(newInput);

  if(enable_shinken_features) {
    var newSelect      = document.createElement('select');
    newSelect.setAttribute('name', pane_prefix + search_prefix + 'value_sel');
    newSelect.setAttribute('id', pane_prefix + search_prefix + nr + '_value_sel');
    add_options(newSelect, priorities, 2);
    newSelect.style.display    = "none";
    newSelect.style.visibility = "hidden";
    newCell0.appendChild(newSelect);
  }

  var calImg = document.createElement('img');
  calImg.src = url_prefix + "themes/"+theme+"/images/calendar.png";
  calImg.className = "cal_icon";
  calImg.alt = "choose date";
  var link   = document.createElement('a');
  link.href  = "javascript:show_cal('" + pane_prefix + search_prefix + nr + "_value')";
  link.setAttribute('id', pane_prefix + search_prefix + nr + '_cal');
  link.style.display    = "none";
  link.style.visibility = "hidden";
  link.appendChild(calImg);
  newCell0.appendChild(link);

  // add second cell
  var img            = document.createElement('input');
  img.type           = 'image';
  img.src            = url_prefix + "themes/"+theme+"/images/remove.png";
  var newCell1       = newRow.insertCell(1);
  newCell1.onclick   = delete_filter_row;
  newCell1.className = "newfilter";
  newCell1.appendChild(img);

  // fill in values from last row
  lastnr=nr-1;
  var lastops = jQuery('#'+pane_prefix + search_prefix + lastnr + '_to');
  if(lastops.length > 0) {
      jQuery('#'+pane_prefix + search_prefix + nr + '_to')[0].selectedIndex    = jQuery('#'+pane_prefix + search_prefix + lastnr + '_to')[0].selectedIndex;
      jQuery('#'+pane_prefix + search_prefix + nr + '_ts')[0].selectedIndex    = jQuery('#'+pane_prefix + search_prefix + lastnr + '_ts')[0].selectedIndex;
      jQuery('#'+pane_prefix + search_prefix + nr + '_value')[0].value         = jQuery('#'+pane_prefix + search_prefix + lastnr + '_value')[0].value;
      jQuery('#'+pane_prefix + search_prefix + nr + '_val_pre')[0].value       = jQuery('#'+pane_prefix + search_prefix + lastnr + '_val_pre')[0].value;
  }
  verify_op(pane_prefix + search_prefix + nr + '_ts');
}

/* remove a row */
function delete_filter_row(event) {
  var row;
  if(event && event.target) {
    row = event.target;
  } else if(event) {
    row = event;
  } else {
    row = this;
  }
  /* find first table row */
  while(row.parentNode != undefined && row.tagName != 'TR') { row = row.parentNode; }
  row.parentNode.deleteRow(row.rowIndex);
  return false;
}

/* add options to a select
 * numbered:
 *   undef = value is lowercase text
 *   1     = value is numbered starting at 0
 *   2     = value is revese numbered
 */
function add_options(select, options, numbered) {
    var x = 0;
    if(numbered == 2) { x = options.length; }
    jQuery.each(options, function(index, text) {
        var opt  = document.createElement('option');
        opt.text = text;
        if(text.match(/^\-+$/)) {
            opt.disabled = true;
        }
        if(numbered) {
            opt.value = x;
        } else {
            opt.value = text.toLowerCase();
        }
        select.options[select.options.length] = opt;
        if(numbered == 2) {
            x--;
        } else {
            x++;
        }
    });
}

/* create a complete new filter pane */
function new_filter(cloneObj, parentObj, btnId) {
  pane_prefix       = btnId.substring(0,4);
  btnId             = btnId.substring(4);
  var index         = btnId.indexOf('_');
  var search_prefix = btnId.substring(0, index+1);
  cloneObj          = cloneObj.substring(4);
  var origObj       = document.getElementById(pane_prefix+search_prefix+cloneObj);
  if(!origObj) {
    if(thruk_debug_js) { alert("ERROR: no elem to clone in new_filter() for: " + pane_prefix + search_prefix + cloneObj); }
  }
  var newObj   = origObj.cloneNode(true);

  var new_prefix = 's' + (parseInt(search_prefix.substring(1)) + 1) + '_';

  // replace ids and names
  var tags = new Array('A', 'INPUT', 'TABLE', 'TR', 'TD', 'SELECT', 'INPUT', 'DIV', 'IMG');
  jQuery.each(tags, function(i, tag) {
      var elems = newObj.getElementsByTagName(tag);
      replaceIdAndNames(elems, pane_prefix+new_prefix);
  });

  // replace id of panel itself
  replaceIdAndNames(newObj, pane_prefix+new_prefix);

  var tblObj   = document.getElementById(parentObj);
  var tblBody  = tblObj.tBodies[0];
  var nextRow  = tblBody.rows.length - 1;
  var nextCell = tblBody.rows[nextRow].cells.length;
  if(nextCell > 2) {
    nextCell = 0;
    tblBody.insertRow(nextRow+1);
    nextRow++;
  }
  var newCell  = tblBody.rows[nextRow].insertCell(nextCell);
  newCell.setAttribute('valign', 'top');
  newCell.appendChild(newObj);

  // hide the original button
  hideElement(pane_prefix + btnId);
  hideBtn = document.getElementById(pane_prefix+new_prefix + 'filter_button_mini');
  if(hideBtn) { hideElement( hideBtn); }
  hideElement(pane_prefix + new_prefix + 'btn_accept_search');
  if(document.getElementById(pane_prefix + new_prefix + 'btn_columns')) {
    hideElement(pane_prefix + new_prefix + 'btn_columns');
  }
  showElement(pane_prefix + new_prefix + 'btn_del_search');

  // hide add button if maximum search boxes reached
  if(maximum_search_boxes > 0 && jQuery('TABLE.filter_box').length >= maximum_search_boxes) {
    hideElement(pane_prefix + new_prefix + 'new_filter');
  }

  hideBtn = document.getElementById(pane_prefix + new_prefix + 'filter_title');
  if(hideBtn) { hideElement(hideBtn); }

  styler = document.getElementById(pane_prefix + new_prefix + 'style_selector');
  if(styler) { styler.parentNode.removeChild(styler); }
}

/* replace ids and names for elements */
function replaceIdAndNames(elems, new_prefix) {
  if (elems == null || ( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
    elems = new Array(elems);
  }
  for(var x = 0; x < elems.length; x++) {
    var elem = elems[x];
    if(elem.id) {
        var new_id = elem.id.replace(/^\w{3}_s\d+_/, new_prefix);
        elem.setAttribute('id', new_id);
    }
    if(elem.name) {
        var new_name = elem.name.replace(/^\w{3}_s\d+_/, new_prefix);
        elem.setAttribute('name', new_name);
    }

    if(ajax_search_enabled && elem.tagName == 'INPUT' && elem.type == 'text') {
      elem.onclick = ajax_search.init;
    }
  };
}

/* replace id and name of a object */
function replace_ids_and_names(elem, new_nr) {
    if(elem.id) {
        var new_id = elem.id.replace(/_\d+$/, '_'+new_nr);
        elem.setAttribute('id', new_id);
    }
    if(elem.name) {
        var new_name = elem.name.replace(/_\d+$/, '_'+new_nr);
        elem.setAttribute('name', new_name);
    }
    return elem
}

/* remove a search panel */
function deleteSearchPane(id) {
  pane_prefix   = id.substring(0,4);
  id            = id.substring(4);
  var index     = id.indexOf('_');
  search_prefix = id.substring(0,index+1);

  var pane  = document.getElementById(pane_prefix + search_prefix + 'filter_pane');
  var table = jQuery(pane.parentNode).parents('TABLE').first()[0];

  var cell = pane.parentNode;
  while(cell.firstChild) {
      child = cell.firstChild;
      cell.removeChild(child);
  }
  cell.parentNode.removeChild(cell);

  // show last "new search" button
  var last_nr = 0;
  for(var x = 0; x<= 99; x++) {
      tst = document.getElementById(pane_prefix + 's'+x+'_' + 'new_filter');
      if(tst && pane_prefix + 's'+x+'_' != search_prefix) { last_nr = x; }
  }
  showElement( pane_prefix + 's'+last_nr+'_' + 'new_filter');

  // realign search panel to 3 per row.
  // first collect all cells from all rows
  var cells = [];
  for(var rowNum = 0; rowNum < table.rows.length; rowNum++) {
      while(table.rows[rowNum].firstChild) {
        var node = table.rows[rowNum].removeChild(table.rows[rowNum].firstChild);
        if(node.nodeType === document.ELEMENT_NODE) cells.push(node);
      }
  }
  var rowNum = 0;
  for(var i = 0; i < cells.length; i++) {
    table.rows[rowNum].appendChild(cells[i]);
    if(i > 0 && (i+1)%3 == 0) {
        rowNum++;
    }
  }
  // remove last row if its emtpy now
  var rowNum = table.rows.length - 1;
  if(table.rows[rowNum].cells.length == 0) {
    table.deleteRow(table.rows[rowNum].rowIndex);
  }

  return false;
}

/* toggle checkbox for attribute filter */
function toggleFilterCheckBox(id) {
  id  = id.substring(0, id.length -1);
  var box = document.getElementById(id);
  if(box.checked) {
    box.checked = false;
  } else {
    box.checked = true;
  }
}

/* toggle all checkbox for attribute filter */
function toggleAllFilterCheckBox(prefix) {
  var box = document.getElementById(prefix+"ht0");
  var state = false;
  if(box.checked) {
    state = true;
  }
  for(var x = 0; x <= 99; x++) {
      var el = document.getElementById(prefix+'ht'+x);
      if(!el) { break; }
      el.checked = state;
  }
}

/* verify operator for search type selects */
function verify_op(event) {
  var selElem;
  if(event && event.target) {
    selElem = event.target;
  } else if(event) {
    selElem = document.getElementById(event);
  } else {
    selElem = document.getElementById(this.id);
  }

  // get operator select
  var opElem = document.getElementById(selElem.id.substring(0, selElem.id.length - 1) + 'o');

  var selValue = selElem.options[selElem.selectedIndex].value;

  // do we have to display the datepicker?
  var calElem = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'cal');
  if(selValue == 'next check' || selValue == 'last check' ) {
    showElement(calElem);
  } else {
    hideElement(calElem);
  }

  var input  = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'value');
  if(enable_shinken_features) {
    var select = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'value_sel');
    if(selValue == 'business impact' ) {
      showElement(select.id);
      hideElement(input.id);
    } else {
      hideElement(select.id);
      showElement(input.id);
    }
  }
  var pre_in = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'val_pre');
  if(selValue == 'custom variable' ) {
    showElement(pre_in.id);
    jQuery(input).css('width', '80px');
  } else {
    hideElement(pre_in.id);
    jQuery(input).css('width', '');
  }

  // check if the right operator are active
  for(var x = 0; x< opElem.options.length; x++) {
    var curOp = opElem.options[x].value;
    if(curOp == '~' || curOp == '!~') {
      // list of fields which have a ~ or !~ operator
      if(   selValue != 'search'
         && selValue != 'host'
         && selValue != 'service'
         && selValue != 'hostgroup'
         && selValue != 'servicegroup'
         && selValue != 'timeperiod'
         && selValue != 'contact'
         && selValue != 'custom variable'
         && selValue != 'comment'
         && selValue != 'event handler'
         && selValue != 'plugin output') {
        // is this currently selected?
        if(x == opElem.selectedIndex) {
          // only = and != are allowed for list searches
          // so set the corresponding one
          if(curOp == '!~') {
              selectByValue(opElem, '!=');
          } else {
              selectByValue(opElem, '=');
          }
        }
        opElem.options[x].style.display = "none";
        opElem.options[x].disabled      = true;
      } else {
        opElem.options[x].style.display = "";
        opElem.options[x].disabled      = false;
      }
    }

    // list of fields which have a <= or >= operator
    if(curOp == '<=' || curOp == '>=') {
      if(   selValue != 'next check'
         && selValue != 'last check'
         && selValue != 'latency'
         && selValue != 'number of services'
         && selValue != 'current attempt'
         && selValue != 'execution time'
         && selValue != '% state change'
         && selValue != 'duration'
         && selValue != 'downtime duration'
         && selValue != 'business impact') {
        // is this currently selected?
        if(x == opElem.selectedIndex) {
          // only <= and >= are allowed for list searches
          selectByValue(opElem, '=');
        }
        opElem.options[x].style.display = "none";
        opElem.options[x].disabled      = true;
      } else {
        opElem.options[x].style.display = "";
        opElem.options[x].disabled      = false;
      }
    }
  }

  input.title = '';
  if(selValue == 'duration') {
    input.title = "Duration: Input type is seconds. You may use w (week) or d (day), h (hour) or m (minutes). Ex.: 10m for 10 minutes.";
  }
  if(selValue == 'downtime duration') {
    input.title = "Downtime Duration: Input type is seconds. You may use w (week) or d (day), h (hour) or m (minutes). Ex.: 10m for 10 minutes.";
  }
  if(selValue == 'execution time') {
    input.title = "Execution Time: Input type is seconds. You may use w (week) or d (day), h (hour) or m (minutes). Ex.: 10m for 10 minutes.";
  }
}

/* remove columns from get parameters when style has changed */
function check_filter_style_changes(form, pageStyle, columnFieldId) {
  var s_data = jQuery(form).serializeArray();
  for(var i=0; i<s_data.length; i++){
    if(s_data[i].name == "style" && s_data[i].value != pageStyle) {
        jQuery('#'+columnFieldId).val("");
    }
  }
  return true;
}


var status_form_clean = true;
function setNoFormClean() {
    status_form_clean = false;
}

/* remove empty values from form to reduce request size */
function remove_empty_form_params(form) {
  if(!status_form_clean) { return true; }
  var s_data = jQuery(form).serializeArray();
  for(var i=0; i<s_data.length; i++){
    var f = s_data[i];
    if(f["name"].match(/_hoststatustypes$/) && f["value"] == "15") {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/_servicestatustypes/) && f["value"] == "31") {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/_(host|service)props/) && f["value"] == "0") {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/_columns_select$/)) {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/^(host|service)_columns$/)) {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/^(referer|bookmarks?|section)$/)) {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
  }
//return false;
  return(true);
}

/* select option from a select by value*/
function selectByValue(select, val) {
  for(var x = 0; x< select.options.length; x++) {
    if(select.options[x].value == val) {
      select.selectedIndex = x;
    } else {
      select.options[x].selected = false;
    }
  }
}

/* toggle visibility of top status informations */
function toggleTopPane() {
  var formInput = document.getElementById('hidetop');
  if(toggleElement('top_pane')) {
    additionalParams['hidetop'] = 0;
    if(formInput) {
        formInput.value = 0;
    }
    document.getElementById('btn_toggle_top_pane').src = url_prefix + "themes/" + theme + "/images/icon_minimize.gif";
  } else {
    additionalParams['hidetop'] = 1;
    if(formInput) {
        formInput.value = 1;
    }
    document.getElementById('btn_toggle_top_pane').src = url_prefix + "themes/" + theme + "/images/icon_maximize.gif";
  }
}

/*******************************************************************************
  ,ad8888ba,        db        88
 d8"'    `"8b      d88b       88
d8'               d8'`8b      88
88               d8'  `8b     88
88              d8YaaaaY8b    88
Y8,            d8""""""""8b   88
 Y8a.    .a8P d8'        `8b  88
  `"Y8888Y"' d8'          `8b 88888888888
*******************************************************************************/

var last_cal_hidden = undefined;
var last_cal_id     = undefined;
function show_cal(id, defaultDate) {
  // make calendar toggle
  var now = new Date;
  if(last_cal_hidden != undefined && (now.getTime() - last_cal_hidden) < 150 && (last_cal_id == undefined || last_cal_id == id )) {
    return;
  }

  last_cal_id   = id;
  var dateObj   = new Date();
  var times     = new Array(0,0,0);

  var parseDate = function(id) {
    var date_val  = document.getElementById(id).value;
    var date_time = date_val.split(" ");
    if(date_time.length == 2) {
      var dates     = date_time[0].split('-');
      var times     = date_time[1].split(':');
      if(times[2] == undefined) {
          times = new Array(0,0,0);
      }
      var dateObj = new Date(dates[0], (dates[1]-1), dates[2], times[0], times[1], times[2]);
    }
    return([dateObj, times]);
  }

  var tmp = parseDate(id);
  if(!tmp[0]) {
    if(defaultDate == undefined) {
        defaultDate = Calendar.printDate(new Date, '%Y-%m-%d %H:%M:%S');
    }
    document.getElementById(id).value = defaultDate;
    tmp = parseDate(id);
  }
  dateObj = tmp[0];
  times   = tmp[1];

  var setDate = function() {
    var newDateObj = new Date(this.selection.print('%Y'), (this.selection.print('%m')-1), this.selection.print('%d'), this.getHours(), this.getMinutes(), times[2]);
    document.getElementById(id).value = Calendar.printDate(newDateObj, '%Y-%m-%d %H:%M:%S');
    document.getElementById(id).value = Calendar.printDate(newDateObj, '%Y-%m-%d %H:%M:%S');
    // change end_date as well if new start date is past end date
    if(id == "start_time") {
        var end_date = document.getElementById("end_time");
        if(end_date) {
            var tmp = parseDate("end_time");
            if(newDateObj.getTime() > tmp[0].getTime()) {
                var endDate = new Date(newDateObj.getTime() + (downtime_duration * 1000));
                end_date.value = Calendar.printDate(endDate, '%Y-%m-%d %H:%M:%S');
            }
        }
    }
    var now = new Date; last_cal_hidden = now.getTime();
    jQuery('.DynarchCalendar-topCont').remove();
  }

  var cal = Calendar.setup({
      time: Calendar.printDate(dateObj, '%H%M'),
      date: Calendar.dateToInt(dateObj),
      showTime: true,
      fdow: 1,
      weekNumbers: true,
      onSelect: setDate,
      onBlur:   setDate,
      onTimeChange: function(c, time) {
        time = time - time%5;
        c.setTime(time, true);
      }
  });
  cal.selection.set(Calendar.dateToInt(dateObj));
  var pos    = ajax_search.get_coordinates(jQuery('#'+id)[0]);
  cal.popup(id, "Br/ / /T/r");
  jQuery('.DynarchCalendar-topCont').css('top', (pos[1]+20)+"px");
}

/*******************************************************************************
 ad88888ba  88888888888        db        88888888ba    ,ad8888ba,  88        88
d8"     "8b 88                d88b       88      "8b  d8"'    `"8b 88        88
Y8,         88               d8'`8b      88      ,8P d8'           88        88
`Y8aaaaa,   88aaaaa         d8'  `8b     88aaaaaa8P' 88            88aaaaaaaa88
  `"""""8b, 88"""""        d8YaaaaY8b    88""""88'   88            88""""""""88
        `8b 88            d8""""""""8b   88    `8b   Y8,           88        88
Y8a     a8P 88           d8'        `8b  88     `8b   Y8a.    .a8P 88        88
 "Y88888P"  88888888888 d8'          `8b 88      `8b   `"Y8888Y"'  88        88
*******************************************************************************/
var ajax_search = {
    max_results     : 12,
    input_field     : 'NavBarSearchItem',
    result_pan      : 'search-results',
    update_interval : 3600, // update at least every hour
    search_type     : 'all',
    size            : 150,
    updating        : false,
    error           : false,

    hideTimer       : undefined,
    base            : new Array(),
    res             : new Array(),
    initialized     : false,
    initialized_t   : false,
    initialized_a   : false,
    cur_select      : -1,
    result_size     : false,
    cur_results     : false,
    cur_pattern     : false,
    timer           : false,
    striped         : false,
    autosubmit      : undefined,
    list            : false,
    templates       : 'no',
    hideempty       : false,
    emptymsg        : undefined,
    show_all        : false,
    dont_hide       : false,
    autoopen        : true,
    append_value_of : undefined,
    stop_events     : false,
    empty           : false,
    emptytxt        : '',
    emptyclass      : '',
    onselect        : undefined,
    onemptyclick    : undefined,
    filter          : undefined,
    regex_matching  : false,
    backend_select  : false,
    button_links    : [],
    search_for_cb   : undefined,

    /* initialize search
     *
     * options are {
     *   url:               url to fetch data
     *   striped:           true/false, everything after " - " is trimmed
     *   autosubmit:        true/false, submit form on select
     *   list:              true/false, string is split by , and suggested by last chunk
     *   templates:         no/templates/both, suggest templates
     *   data:              search base data
     *   hideempty:         true/false, hide results when there are no hits
     *   add_prefix:        true/false, add ho:... prefix
     *   append_value_of:   id of input field to append to the original url
     *   empty:             remove text on first access
     *   emptytxt:          text when empty
     *   emptyclass:        class when empty
     *   onselect:          run this function after selecting something
     *   onemptyclick:      when clicking on the empty button
     *   filter:            run this function as additional filter
     *   backend_select:    append value of this backend selector
     *   button_links:      prepend links to buttons on top of result
     *   regex_matching:    match with regular expressions
     *   search_for_cb:     callback to alter the search input
     * }
     */
    init: function(elem, type, options) {
        if(elem && elem.id) {
        } else if(this.id) {
          elem = this;
        } else {
          if(thruk_debug_js) { alert("ERROR: got no element id in ajax_search.init(): " + elem); }
          return false;
        }

        if(options == undefined) { options = {}; };

        ajax_search.url = url_prefix + 'cgi-bin/status.cgi?format=search';
        ajax_search.input_field = elem.id;

        if(ajax_search.stop_events == true) {
            return false;
        }

        if(options.striped != undefined) {
            ajax_search.striped = options.striped;
        }
        if(options.autosubmit != undefined) {
            ajax_search.autosubmit = options.autosubmit;
        }
        if(options.list != undefined) {
            ajax_search.list = options.list;
        }
        if(options.templates != undefined) {
            ajax_search.templates = options.templates;
        } else {
            ajax_search.templates = 'no';
        }
        if(options.hideempty != undefined) {
            ajax_search.hideempty = options.hideempty;
        }
        if(options.add_prefix != undefined) {
            ajax_search.add_prefix = options.add_prefix;
        }
        ajax_search.emptymsg = 'no results found';
        if(options.emptymsg != undefined) {
            ajax_search.emptymsg = options.emptymsg;
        }

        if(options.append_value_of != undefined) {
            append_value_of = options.append_value_of;
        } else {
            append_value_of = ajax_search.append_value_of;
        }

        if(options.backend_select != undefined) {
            backend_select = options.backend_select;
        } else {
            backend_select = ajax_search.backend_select;
        }

        ajax_search.button_links = [];
        if(options.button_links != undefined) {
            ajax_search.button_links = options.button_links;
        }

        ajax_search.empty = false;
        if(options.empty != undefined) {
            ajax_search.empty = options.empty;
        }
        if(options.emptytxt != undefined) {
            ajax_search.emptytxt = options.emptytxt;
        }
        if(options.emptyclass != undefined) {
            ajax_search.emptyclass = options.emptyclass;
        }
        ajax_search.onselect = undefined;
        if(options.onselect != undefined) {
            ajax_search.onselect = options.onselect;
        }
        ajax_search.onemptyclick = undefined;
        if(options.onemptyclick != undefined) {
            ajax_search.onemptyclick = options.onemptyclick;
        }
        ajax_search.filter = undefined;
        if(options.filter != undefined) {
            ajax_search.filter = options.filter;
        }
        ajax_search.search_for_cb = undefined;
        if(options.search_for_cb != undefined) {
            ajax_search.search_for_cb = options.search_for_cb;
        }

        var input = document.getElementById(ajax_search.input_field);
        if(input.disabled) { return false; }
        ajax_search.size = jQuery(input).width();
        if(ajax_search.size < 100) {
            /* minimum is 100px */
            ajax_search.size = 100;
        }

        if(ajax_search.empty == true) {
            if(input.value == ajax_search.emptytxt) {
                jQuery(input).removeClass(ajax_search.emptyclass);
                input.value = "";
            }
        }

        ajax_search.show_all = false;
        var panel = document.getElementById(ajax_search.result_pan);
        if(panel) {
            panel.style.overflowY="";
            panel.style.height="";
        }

        // set type from select
        var type_selector_id = elem.id.replace('_value', '_ts');
        var selector = document.getElementById(type_selector_id);
        ajax_search.search_type = 'all';
        if(!iPhone) {
            addEvent(input, 'keyup', ajax_search.suggest);
            addEvent(input, 'blur',  ajax_search.hide_results);
        }

        var op_selector_id = elem.id.replace('_value', '_to');
        var op_sel         = document.getElementById(op_selector_id);
        ajax_search.regex_matching = false;
        if(op_sel != undefined) {
            var val = jQuery(op_sel).val();
            if(val == '~' || val == '!~') {
                ajax_search.regex_matching = true;
            }
        }
        if(options.regex_matching != undefined) {
            ajax_search.regex_matching = options.regex_matching;
        }

        search_url = ajax_search.url;
        if(options.url != undefined) {
            search_url = options.url;
        }

        if(type != undefined) {
            // type can be a callback
            if(typeof(type) == 'function') {
                type = type();
            }
            ajax_search.search_type = type;
            if(!search_url.match(/type=/)) {
                search_url = search_url + "&type=" + type;
            }
        } else {
            type = 'all';
        }

        var appended_value;
        if(append_value_of) {
            var el = document.getElementById(append_value_of);
            if(el) {
                search_url     = search_url + el.value;
                appended_value = el.value;
            } else {
                search_url     = ajax_search.url;
                appended_value = '';
            }
        }
        if(backend_select) {
            var sel = document.getElementById(backend_select);
            // only if enabled
            if(sel && !sel.disabled) {
                var backends = jQuery('#'+backend_select).val();
                if(backends != undefined) {
                    if(typeof(backends) == 'string') { backends = [backends]; }
                    jQuery.each(backends, function(i, val) {
                        search_url = search_url + '&backend=' + val;
                    });
                }
            }
        }

        input.setAttribute("autocomplete", "off");
        if(!iPhone && !internetExplorer) {
            ajax_search.dont_hide = true;
            input.blur();   // blur & focus the element, otherwise the first
            input.focus();  // click would result in the browser autocomplete
            ajax_search.dont_hide = false;
        }

        if(selector && selector.tagName == 'SELECT') {
            var search_type = selector.options[selector.selectedIndex].value;
            if(   search_type == 'host'
               || search_type == 'hostgroup'
               || search_type == 'service'
               || search_type == 'servicegroup'
               || search_type == 'timeperiod'
               || search_type == 'priority'
               || search_type == 'custom variable'
               || search_type == 'contact'
               || search_type == 'event handler'
            ) {
                ajax_search.search_type = search_type;
            }
            if(search_type == 'parent') {
                ajax_search.search_type = 'host';
            }
            if(search_type == 'check period') {
                ajax_search.search_type = 'timeperiod';
            }
            if(search_type == 'notification period') {
                ajax_search.search_type = 'timeperiod';
            }
            if(search_type == 'business impact') {
                ajax_search.search_type = 'priority';
            }
            if(   search_type == 'comment'
               || search_type == 'next check'
               || search_type == 'last check'
               || search_type == 'latency'
               || search_type == 'number of services'
               || search_type == 'current attempt'
               || search_type == 'execution time'
               || search_type == '% state change'
               || search_type == 'duration'
               || search_type == 'downtime duration'
            ) {
                ajax_search.search_type = 'none';
            }
        }
        if(input.id.match(/_value$/) && ajax_search.search_type == "custom variable") {
            ajax_search.search_type = "none"
            var varFieldId = input.id.replace(/_value$/, '_val_pre');
            var varField   = document.getElementById(varFieldId);
            if(varField) {
                ajax_search.search_type = "custom value"
                search_url = search_url + "&type=custom value&var=" + varField.value;
            }
        }
        if(ajax_search.search_type == 'none') {
            removeEvent( input, 'keyup', ajax_search.suggest );
            return true;
        } else {
            if(   search_type == 'event handler'
               || search_type == 'contact'
            ) {
                if(!search_url.match(/type=/)) {
                    search_url = search_url + "&type=" + ajax_search.search_type;
                }
            }
        }

        var date = new Date;
        var now  = parseInt(date.getTime() / 1000);
        // update every hour (frames searches wont update otherwise)
        if(   ajax_search.initialized
           && now < ajax_search.initialized + ajax_search.update_interval
           && (    append_value_of == undefined && ajax_search.initialized_t == type
               || (append_value_of != undefined && ajax_search.initialized_a == appended_value )
              )
           && ajax_search.initialized_u == search_url
        ) {
            ajax_search.suggest();
            return false;
        }

        ajax_search.initialized   = now;
        ajax_search.initialized_t = type;
        ajax_search.initialized_a = undefined;
        if(append_value_of) {
            ajax_search.initialized_a = appended_value;
        }
        ajax_search.initialized_u = search_url;

        // disable autocomplete
        var tmpElem = input;
        while(tmpElem && tmpElem.parentNode) {
            tmpElem = tmpElem.parentNode;
            if(tmpElem.tagName == 'FORM') {
                addEvent(tmpElem, 'submit', ajax_search.hide_results);
                tmpElem.setAttribute("autocomplete", "off");
            }
        }

        if(options.data != undefined) {
            ajax_search.base = options.data;
            ajax_search.suggest();
        } else {
             ajax_search.updating=true;
             ajax_search.error=false;

            // show searching results
            ajax_search.base = {};
            ajax_search.suggest();

             // fill data store
            jQuery.ajax({
                url: search_url,
                type: 'POST',
                success: function(data) {
                    ajax_search.updating=false;
                    ajax_search.base = data;
                    if(ajax_search.autoopen == true || panel.style.visibility == 'visible') {
                        ajax_search.suggest();
                    }
                    ajax_search.autoopen = true;
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    ajax_search.error=errorThrown;
                    if(ajax_search.error == undefined || ajax_search.error == "") {
                        ajax_search.error = "server unavailable";
                    }
                    ajax_search.updating=false;
                    ajax_search.show_results([]);
                    ajax_search.initialized = false;
                }
            });
        }

        if(!iPhone) {
            addEvent(document, 'keydown', ajax_search.arrow_keys);
            addEvent(document, 'click', ajax_search.hide_results);
        }

        return false;
    },

    /* hide the search results */
    hide_results: function(event, immediately, setfocus) {
        if(ajax_search.dont_hide) { return; }
        if(event && event.target) {
        }
        else {
            event  = this;
        }
        try {
            // dont hide search result if clicked on the input field
            if(event.type != "blur" && event.target.tagName == 'INPUT') { return; }
            // don't close if blur is due to a click inside the search results
            if(event.type == "blur" || event.type == "click") {
                var result_panel = document.getElementById(ajax_search.result_pan);
                var p = event.target;
                var found = false;
                while(p.parentNode) {
                    if(p == result_panel) {
                        found = true;
                        break;
                    }
                    p = p.parentNode;
                }
                if(found) {
                    window.clearTimeout(ajax_search.hideTimer);
                    return;
                }
            }
        }
        catch(err) {
            // doesnt matter
        }
        var panel = document.getElementById(ajax_search.result_pan);
        if(!panel) { return; }
        /* delay hiding a little moment, otherwise the click
         * on the suggestion would be cancel as the panel does
         * not exist anymore
         */
        if(immediately != undefined) {
            hideElement(ajax_search.result_pan);
            if(setfocus) {
                ajax_search.stop_events = true;
                window.setTimeout("ajax_search.stop_events=false;", 200);
                var input = document.getElementById(ajax_search.input_field);
                input.focus();
            }
        }
        else if(ajax_search.cur_select == -1) {
            window.clearTimeout(ajax_search.hideTimer);
            ajax_search.hideTimer = window.setTimeout("if(ajax_search.dont_hide==false){fade('"+ajax_search.result_pan+"', 300)}", 150);
        }
    },

    /* wrapper around suggest_do() to avoid multiple running searches */
    suggest: function(evt) {
        window.clearTimeout(ajax_search.timer);
        // dont suggest on enter
        evt = (evt) ? evt : ((window.event) ? event : null);
        if(evt) {
            var keyCode = evt.keyCode;
            // dont suggest on
            if(   keyCode == 13     // enter
               || keyCode == 108    // KP enter
               || keyCode == 27     // escape
               || keyCode == 16     // shift
               || keyCode == 20     // capslock
               || keyCode == 17     // ctrl
               || keyCode == 18     // alt
               || keyCode == 91     // left windows key
               || keyCode == 92     // right windows key
               || keyCode == 33     // page up
               || keyCode == 34     // page down
               || evt.altKey == true
               || evt.ctrlKey == true
               || evt.metaKey == true
               //|| evt.shiftKey == true // prevents suggesting capitals
            ) {
                return false;
            }
            // tab on keyup opens suggestions for wrong input
            if(keyCode == 9 && evt.type == "keyup") {
                return false;
            }
        }

        ajax_search.timer = window.setTimeout("ajax_search.suggest_do()", 100);
        return true;
    },

    /* search some hosts to suggest */
    suggest_do: function() {
        var input;
        var input = document.getElementById(ajax_search.input_field);
        if(!input) { return; }
        if(ajax_search.base == undefined || ajax_search.base.length == 0) { return; }

        // business impact prioritys are fixed
        if(ajax_search.search_type == 'priority') {
            ajax_search.base = [{ name: 'prioritys', data: ["1","2","3","4","5"] }];
        }

        pattern = input.value;
        if(ajax_search.search_for_cb) {
            pattern = ajax_search.search_for_cb(pattern)
        }
        if(ajax_search.list) {
            /* only use the last list element for search */
            var regex  = new RegExp(ajax_search.list, 'g');
            var range  = jQuery(input).getSelection();
            var before = pattern.substr(0, range.start);
            var after  = pattern.substr(range.start);
            var rever  = reverse(before);
            var index  = rever.search(regex);
            if(index != -1) {
                var index2  = after.search(regex);
                if(index2 != -1) {
                    pattern = reverse(rever.substr(0, index)) + after.substr(0, index2);
                } else {
                    pattern = reverse(rever.substr(0, index)) + after;
                }
            } else {
                // possible on the first elem, then we search for the first delimiter after the cursor
                var index  = pattern.search(regex);
                if(index != -1) {
                    pattern = pattern.substr(0, index);
                }
            }
        }
        if(pattern.length >= 1 || ajax_search.search_type != 'all') {

            prefix = pattern.substr(0,3);
            if(prefix == 'ho:' || prefix == 'hg:' || prefix == 'se:' || prefix == 'sg:') {
                pattern = pattern.substr(3);
            }

            // remove empty strings from pattern array
            pattern = get_trimmed_pattern(pattern);
            var results = new Array();
            jQuery.each(ajax_search.base, function(index, search_type) {
                var sub_results = new Array();
                var top_hits = 0;
                if(   (ajax_search.search_type == 'all' && search_type.name != 'timeperiods')
                   || (ajax_search.search_type == 'full')
                   || (ajax_search.templates == "templates" && search_type.name == ajax_search.initialized_t + " templates")
                   || (ajax_search.templates != "templates" && ajax_search.search_type + 's' == search_type.name)
                   || (ajax_search.templates == "both" && ( search_type.name == ajax_search.initialized_t + " templates" || ajax_search.search_type + 's' == search_type.name ))
                  ) {
                  jQuery.each(search_type.data, function(index, data) {
                      var name = data;
                      var alias = '';
                      if(data && data['name']) {
                          name = data['name'];
                      }
                      var search_name = name;
                      if(data && data['alias']) {
                          alias = data['alias'];
                          search_name = search_name+' '+alias;
                      }
                      result_obj = new Object({ 'name': name, 'relevance': 0 });
                      var found = 0;
                      jQuery.each(pattern, function(i, sub_pattern) {
                          var index = search_name.toLowerCase().indexOf(sub_pattern.toLowerCase());
                          if(index != -1) {
                              found++;
                              if(index == 0) { // perfect match, starts with pattern
                                  result_obj.relevance += 100;
                              } else {
                                  result_obj.relevance += 1;
                              }
                          } else {
                              if(sub_pattern == "*") {
                                found++;
                                result_obj.relevance += 1;
                                return;
                              }
                              var re;
                              try {
                                re = new RegExp(sub_pattern, "gi");
                              } catch(err) {
                                console.log('regex failed: ' + sub_pattern);
                                console.log(err);
                                ajax_search.error = "regex failed: "+err;
                                return(false);
                              }
                              if(re != undefined && ajax_search.regex_matching && search_name.match(re)) {
                                  found++;
                                  result_obj.relevance += 1;
                              }
                          }
                      });
                      // additional filter?
                      var rt = true;
                      if(ajax_search.filter != undefined) {
                          rt = ajax_search.filter(name, search_type);
                      }
                      // only if all pattern were found
                      if(rt && found == pattern.length) {
                          result_obj.display = name;
                          if(alias && name != alias) {
                            result_obj.display = name+" - "+alias;
                          }
                          result_obj.sorter = (result_obj.relevance) + result_obj.name;
                          sub_results.push(result_obj);
                          if(result_obj.relevance >= 100) { top_hits++; }
                      }
                  });
                }
                if(sub_results.length > 0) {
                    sub_results.sort(sort_by('sorter', false));
                    results.push(Object({ 'name': search_type.name, 'results': sub_results, 'top_hits': top_hits }));
                }
            });

            ajax_search.cur_results = results;
            ajax_search.cur_pattern = pattern;
            ajax_search.show_results(results, pattern, ajax_search.cur_select);
        }
        else {
            ajax_search.hide_results();
        }
    },

    /* present the results */
    show_results: function(results, pattern, selected) {
        var panel = document.getElementById(ajax_search.result_pan);
        var input = document.getElementById(ajax_search.input_field);
        if(!panel) { return; }
        if(!input) { return; }

        results.sort(sort_by('top_hits', false));

        var resultHTML = '<ul>';
        if(ajax_search.button_links) {
            jQuery.each(ajax_search.button_links, function(i, btn) {
                resultHTML += '<li class="'+(btn.cls ? ' '+btn.cls+' ' : '')+'"><b>';
                resultHTML += '<a href="" class="item" onclick="jQuery(\'#'+btn.id+'\').click(); return false;" style="width:'+ajax_search.size+'px;">';
                if(btn.icon) {
                    resultHTML += '<img src="'+ url_prefix + 'themes/' + theme + '/images/' + btn.icon+'">';
                }
                resultHTML += btn.text;
                resultHTML += '<\/b><\/a><\/li>';
            });
        }
        var x = 0;
        var results_per_type = Math.ceil(ajax_search.max_results / results.length);
        ajax_search.res   = new Array();
        var has_more = 0;
        jQuery.each(results, function(index, type) {
            var cur_count = 0;
            var name = type.name.substring(0,1).toUpperCase() + type.name.substring(1);
            if(type.results.length == 1) { name = name.substring(0, name.length -1); }
            name = name.replace(/ss$/, 's');
            resultHTML += '<li><b><i>' + ( type.results.length ) + ' ' + name + '<\/i><\/b><\/li>';
            jQuery.each(type.results, function(index, data) {
                if(ajax_search.show_all || cur_count <= results_per_type) {
                    var name = data.display || data.name || "";
                    jQuery.each(pattern, function(index, sub_pattern) {
                        if(ajax_search.regex_matching && sub_pattern != "*") {
                            var re = new RegExp('('+sub_pattern+')', "gi");
                            // only replace parts of the string which are not bold yet
                            var parts = name.split(/(<b>.*?<\/b>)/);
                            jQuery.each(parts, function(index2, part) {
                                if(!part.match(/^<b>/)) {
                                    parts[index2] = part.replace(re, "<b>$1<\/b>");
                                }
                            });
                            name = parts.join("");
                        } else {
                            name = name.toLowerCase().replace(sub_pattern.toLowerCase(), "<b>" + sub_pattern + "<\/b>");
                        }
                    });
                    var classname = "item";
                    if(selected != -1 && selected == x) {
                        classname = "item ajax_search_selected";
                    }
                    var prefix = '';
                    if(ajax_search.search_type == "all" || ajax_search.search_type == "full" || ajax_search.add_prefix == true) {
                        if(type.name == 'hosts')             { prefix = 'ho:'; }
                        if(type.name == 'host templates')    { prefix = 'ht:'; }
                        if(type.name == 'hostgroups')        { prefix = 'hg:'; }
                        if(type.name == 'services')          { prefix = 'se:'; }
                        if(type.name == 'service templates') { prefix = 'st:'; }
                        if(type.name == 'servicegroups')     { prefix = 'sg:'; }
                    }
                    var id = "suggest_item_"+x
                    if(type.name == 'icons') {
                        file = data.display.split(" - ");
                        name = "<img src='" + file[1] + "' style='vertical-align: text-bottom; width: 16px; height: 16px;'> " + file[0];
                    }
                    name        = name.replace(/\ \(disabled\)$/, '<span style="color: #EB6900; margin-left: 20px;"> (disabled)<\/span>');
                    resultHTML += '<li><a href="" class="' + classname + '" style="width:'+ajax_search.size+'px;" id="'+id+'" rev="' + prefix+data.name +'" onclick="ajax_search.set_result(this.rev); return false;" title="' + data.display + '"> ' + name +'<\/a><\/li>';
                    ajax_search.res[x] = prefix+data.name;
                    x++;
                    cur_count++;
                } else {
                    has_more = 1;
                }
            });
        });
        if(has_more == 1) {
            var id = "suggest_item_"+x
            var classname = "item";
            if(selected != -1 && selected == x) {
                classname = "item ajax_search_selected";
            }
            resultHTML += '<li> <a href="" class="' + classname + '" style="width:'+ajax_search.size+'px;" id="'+id+'" rev="more" onmousedown="ajax_search.set_result(this.rev); return false;"><b>more...<\/b><\/a><\/li>';
            x++;
        }
        ajax_search.result_size = x;
        if(results.length == 0) {
            resultHTML += '<li>';
            if(ajax_search.error) {
                resultHTML += '<a href="#"><span style="color:red;">error: '+ajax_search.error+'</span></a>';
            }
            else if(ajax_search.updating) {
                resultHTML += '<a href="#"><img src="'+ url_prefix + 'themes/' + theme + '/images/loading-icon.gif" width=16 height=16 style="vertical-align: text-bottom;"> loading...</a>';
            } else {
                resultHTML += '<a href="#" onclick="ajax_search.onempty()">'+ ajax_search.emptymsg +'</a>';
            }
            resultHTML += '</li>';
            if(ajax_search.hideempty) {
                ajax_search.hide_results();
                return;
            }
        }
        resultHTML += '<\/ul>';

        panel.innerHTML = resultHTML;

        var style     = panel.style;
        var coords;
        if(jQuery(input).hasClass("NavBarSearchItem")) {
            // input is wraped in deletable icon span
            coords    = jQuery(input.parentNode).position();
        } else {
            coords    = jQuery(input).offset();
        }
        style.left    = coords.left + "px";
        style.top     = (coords.top + input.offsetHeight + 2) + "px";
        style.display = "block";
        style.width   = ( ajax_search.size -2 ) + "px";

        if(jQuery(input).hasClass("NavBarSearchItem")) {
            style.top   = (coords.top + input.offsetHeight - 4) + "px";
            style.width = ( ajax_search.size + 28 ) + "px";
        }

        /* move dom node to make sure it scrolls with the input field */
        if(jQuery(input).hasClass("NavBarSearchItem")) {
            var tmpElem = input;
            var x = 0;
            // put result div below the form, otherwise clicking a type header would result in a redirect to undefined (#197)
            while(tmpElem && tmpElem.parentNode && x < 7) {
                if(tmpElem.tagName != 'UL') {
                    tmpElem = tmpElem.parentNode;
                }
                x++;
            }
            jQuery('#'+ajax_search.result_pan).insertAfter(tmpElem);
        } else {
            jQuery('#'+ajax_search.result_pan).appendTo('BODY');
        }

        showElement(panel);
        ajax_search.stop_events = true;
        window.setTimeout("ajax_search.stop_events=false;", 200);
        ajax_search.dont_hide=true;
        window.setTimeout("ajax_search.dont_hide=false", 500);
        try { // Error: Can't move focus to the control because it is invisible, not enabled, or of a type that does not accept the focus.
            input.focus();
        } catch(err) {}
    },

    onempty: function() {
        if(ajax_search.onemptyclick != undefined) {
            ajax_search.onemptyclick();
        }
    },

    /* set the value into the input field */
    set_result: function(value) {
        if(value == 'more' || (value == undefined && ajax_search.res.length == ajax_search.cur_select)) {
            window.clearTimeout(ajax_search.hideTimer);
            var panel = document.getElementById(ajax_search.result_pan);
            if(panel) {
                panel.style.overflowY="scroll";
                panel.style.height=jQuery(panel).height()+"px";
            }
            ajax_search.show_all = true;
            ajax_search.show_results(ajax_search.cur_results, ajax_search.cur_pattern, ajax_search.cur_select);
            window.clearTimeout(ajax_search.hideTimer);
            return true;
        }

        if(ajax_search.striped && value != undefined) {
            var values = value.split(" - ", 2);
            value = values[0];
        }

        var input   = document.getElementById(ajax_search.input_field);

        var cursorpos = undefined;
        if(ajax_search.list) {
            var pattern = input.value;
            var regex   = new RegExp(ajax_search.list, 'g');
            var range   = jQuery(input).getSelection();
            var before  = pattern.substr(0, range.start);
            var after   = pattern.substr(range.start);
            var rever   = reverse(before);
            var index   = rever.search(regex);
            if(index != -1) {
                before    = before.substr(0, before.length - index);
                cursorpos = before.length + value.length;
                value     = before + value + after;
            } else {
                // possible on the first elem, then we just add everything after the first delimiter
                var index  = pattern.search(regex);
                if(index != -1) {
                    cursorpos = value.length;
                    value     = value + pattern.substr(index);
                }
            }
        }

        input.value = value;
        ajax_search.cur_select = -1;
        ajax_search.hide_results(null, 1, 1);
        input.focus();
        if(cursorpos) {
            setCaretToPos(input, cursorpos);
        }

        // close suggestions after select
        window.clearTimeout(ajax_search.timer);
        ajax_search.dont_hide==false;
        window.setTimeout('ajax_search.hide_results(null, 1, 1);', 100);

        if(ajax_search.onselect != undefined) {
            return ajax_search.onselect(input);
        }

        if(( ajax_search.autosubmit == undefined
             && (
                    jQuery(input).hasClass("NavBarSearchItem")
                 || ajax_search.input_field == "data.username"
                 || ajax_search.input_field == "data.name"
                 )
           )
           || ajax_search.autosubmit == true
           ) {
            var tmpElem = input;
            while(tmpElem && tmpElem.parentNode) {
                tmpElem = tmpElem.parentNode;
                if(tmpElem.tagName == 'FORM') {
                    tmpElem.submit();
                    return false;
                }
            }
            return false;
        } else {
            return false;
        }
    },

    /* eventhandler for arrow keys */
    arrow_keys: function(evt) {
        evt              = (evt) ? evt : ((window.event) ? event : null);
        if(!evt) { return false; }
        var input        = document.getElementById(ajax_search.input_field);
        var panel        = document.getElementById(ajax_search.result_pan);
        var focus        = false;
        var keyCode      = evt.keyCode;
        var navigateUp   = keyCode == 38;
        var navigateDown = keyCode == 40;

        // arrow keys
        if((!evt.ctrlKey && !evt.metaKey) && panel.style.display != 'none' && (navigateUp || navigateDown)) {
            if(navigateDown && ajax_search.cur_select == -1) {
                ajax_search.cur_select = 0;
                focus = true;
            }
            else if(navigateUp && ajax_search.cur_select == -1) {
                ajax_search.cur_select = ajax_search.result_size - 1;
                focus = true;
            }
            else if(navigateDown) {
                if(ajax_search.result_size > ajax_search.cur_select + 1) {
                    ajax_search.cur_select++;
                    focus = true;
                } else {
                    ajax_search.cur_select = -1;
                    input.focus();
                }
            }
            else if(navigateUp) {
                ajax_search.cur_select--;
                if(ajax_search.cur_select < 0) {
                    ajax_search.cur_select = -1;
                    input.focus();
                }
                else {
                    focus = true;
                }
            }
            ajax_search.show_results(ajax_search.cur_results, ajax_search.cur_pattern, ajax_search.cur_select);
            if(focus) {
                var el = document.getElementById('suggest_item_'+ajax_search.cur_select);
                if(el) {
                    el.focus();
                }
            }
            // ie does not support preventDefault, setting returnValue works
            evt.preventDefault ? evt.preventDefault() : evt.returnValue = false;
            return false;
        }
        // return or enter
        if(keyCode == 13 || keyCode == 108) {
            if(ajax_search.cur_select == -1) {
                return true
            }
            if(ajax_search.set_result(ajax_search.res[ajax_search.cur_select])) {
                return false;
            }
            evt.preventDefault ? evt.preventDefault() : evt.returnValue = false;
            return false
        }
        // hit escape
        if(keyCode == 27) {
            ajax_search.hide_results(undefined, true);
            evt.preventDefault ? evt.preventDefault() : evt.returnValue = false;
            return false;
        }
        return true;
    },

    /* return coordinates for given element */
    get_coordinates: function(element) {
        var offsetLeft = 0;
        var offsetTop = 0;
        while(element.offsetParent){
            offsetLeft += element.offsetLeft;
            offsetTop += element.offsetTop;
            if(element.scrollTop > 0){
                offsetTop -= element.scrollTop;
            }
            element = element.offsetParent;
        }
        return [offsetLeft, offsetTop];
    },

    reset: function() {
        if(ajax_search.empty) {
            var input = document.getElementById(ajax_search.input_field);
            jQuery(input).addClass(ajax_search.emptyclass);
            jQuery(input).val(ajax_search.emptytxt);
        }
    }
}


/*******************************************************************************
GRAPHITE
*******************************************************************************/
function graphite_format_date(date) {
    var d1=new Date(date*1000);

    var curr_year = d1.getFullYear();

    var curr_month = d1.getMonth() + 1; //Months are zero based
    if (curr_month < 10)
        curr_month = "0" + curr_month;

    var curr_date = d1.getDate();
    if (curr_date < 10)
        curr_date = "0" + curr_date;

    var curr_hour = d1.getHours();
    if (curr_hour < 10)
        curr_hour = "0" + curr_hour;

    var curr_min = d1.getMinutes();
    if (curr_min < 10)
        curr_min = "0" + curr_min;

    return curr_hour + "%3A" + curr_min + "_" +curr_year + curr_month + curr_date ;
}

function graphite_unformat_date(str) {
    debug("STR : "+str);
    //23:59_20130125
    var year,month,hour,day,minute;
    hour=str.substring(0,2);
    minute=str.substring(3,5);
    year=str.substring(6,10);
    month=str.substring(10,12)-1;
    day=str.substring(12,14);
    debug(year, month, day, hour, minute);
    var date=new Date(year, month, day, hour, minute);

    debug("date"+date);
    return date.getTime()/1000;
}

function set_graphite_img(start, end, id) {
    //23:59_20130125
    var date_start = new Date(start * 1000);
    var date_end   = new Date(end * 1000);

    var newUrl = graph_url + "&from=" + graphite_format_date(start) + "&until=" + graphite_format_date(end);
    debug(newUrl);

    jQuery('#graphitewaitimg').css('display', 'block');

    jQuery('#graphiteimg').load(function() {
      jQuery('#graphiteimg').css('display' , 'block');
      jQuery('#graphiteerr').css('display' , 'none');
      jQuery('#graphitewaitimg').css({'display': 'none', 'position': 'absolute'});
    })
    .error(function(err) {
      jQuery('#graphitewaitimg').css({'display': 'none', 'position': 'inherit'});
      jQuery('#graphiteimg').css('display' , 'none');
      jQuery('#graphiteerr').css('display' , 'block');
    });

    jQuery('#graphiteerr').css('display' , 'none');
    jQuery('#graphiteimg').attr('src', newUrl);

    // set style of buttons
    if(id) {
        id=id.replace(/^#/g, '');
        for(x=1;x<=5;x++) {
            obj = document.getElementById("graphite_th"+x);
            styleElements(obj, "original", 1);
        }
        obj = document.getElementById(id);
        styleElements(obj, "commentEven pnpSelected", 1);
    } else {
        // get id from hash
        if(window.location.hash != '#') {
            var values = window.location.hash.split("/");
            if(values[0]) {
                id = values[0].replace(/^#/, '');
            }
        }
    }

    if(id) {
        // replace history otherwise we have to press back twice
        var newhash = "#" + id + "/" + start + "/" + end;
        if (history.replaceState) {
            history.replaceState({}, "", newhash);
        } else {
            window.location.replace(newhash);
        }
    }

    // reset reload timer for page
    resetRefresh();

    return false;
}
function move_graphite_img(factor) {
    var urlArgs = new Object(toQueryParams(jQuery('#graphiteimg').attr('src')));

    start = graphite_unformat_date(urlArgs["from"]);
    end   = graphite_unformat_date(urlArgs["until"]);

    diff  = end - start;

    start = parseInt(diff * factor) + parseInt(start);
    end   = parseInt(diff * factor) + parseInt(end);

    return set_graphite_img(start, end);
}


/*******************************************************************************
88888888ba  888b      88 88888888ba
88      "8b 8888b     88 88      "8b
88      ,8P 88 `8b    88 88      ,8P
88aaaaaa8P' 88  `8b   88 88aaaaaa8P'
88""""""'   88   `8b  88 88""""""'
88          88    `8b 88 88
88          88     `8888 88
88          88      `888 88
*******************************************************************************/

function set_png_img(start, end, id, source) {
    if(start  == undefined) { start  = pnp_start; }
    if(end    == undefined) { end    = pnp_end; }
    if(source == undefined) { source = pnp_source; }
    var newUrl = pnp_url + "&start=" + start + "&end=" + end+"&source="+source;
    //debug(newUrl);

    pnp_start = start;
    pnp_end   = end;

    jQuery('#pnpwaitimg').css('display', 'block');

    jQuery('#pnpimg').load(function() {
      jQuery('#pnpimg').css('display' , 'block');
      jQuery('#pnperr').css('display' , 'none');
      jQuery('#pnpwaitimg').css({'display': 'none', 'position': 'absolute'});
    })
    .error(function(err) {
      jQuery('#pnpwaitimg').css({'display': 'none', 'position': 'inherit'});
      jQuery('#pnpimg').css('display' , 'none');
      jQuery('#pnperr').css('display' , 'block');
    });

    jQuery('#pnperr').css('display' , 'none');
    jQuery('#pnpimg').attr('src', newUrl);

    // set style of buttons
    if(id) {
        id=id.replace(/^#/g, '');
        for(x=1;x<=5;x++) {
            obj = document.getElementById("pnp_th"+x);
            styleElements(obj, "original", 1);
        }
        obj = document.getElementById(id);
        styleElements(obj, "commentEven pnpSelected", 1);
    } else {
        // get id from hash
        id = get_hash();
    }

    if(id) {
        // replace history otherwise we have to press back twice
        set_hash(id + "/" + start + "/" + end + "/" + source);
    }

    // reset reload timer for page
    resetRefresh();

    return false;
}

function move_png_img(factor) {
    var urlArgs = new Object(toQueryParams(jQuery('#pnpimg').attr('src')));

    start = urlArgs["start"];
    end   = urlArgs["end"];
    diff  = end - start;

    start = parseInt(diff * factor) + parseInt(start);
    end   = parseInt(diff * factor) + parseInt(end);

    return set_png_img(start, end);
}

function set_histou_img(start, end, id, source) {
    if(start  == undefined) { start  = histou_start; }
    if(end    == undefined) { end    = histou_end; }
    if(source == undefined) { source = histou_source; }

    histou_start = start;
    histou_end   = end;

    var getParamFrom = "&from=" + (start*1000);
    var getParamTo = "&to=" + (end*1000);
    var newUrl = histou_frame_url + getParamFrom + getParamTo + '&panelId='+source;

    //add timerange to iconlink, so the target graph matches the preview
    jQuery("#histou_graph_link").attr("href", histou_url + getParamFrom + getParamTo);

    jQuery('#pnpwaitimg').css('display', 'block');

    jQuery('#histou_iframe').load(function() {
      jQuery('#pnpwaitimg').css({'display': 'none', 'position': 'absolute'});
    })
    .error(function(err) {
      jQuery('#pnpwaitimg').css({'display': 'none', 'position': 'inherit'});
    });

    jQuery('#histou_iframe').attr('src', newUrl);

    // set style of buttons
    if(id) {
        id=id.replace(/^#/g, '');
        for(x=1;x<=5;x++) {
            obj = document.getElementById("histou_th"+x);
            styleElements(obj, "original", 1);
        }
        obj = document.getElementById(id);
        styleElements(obj, "commentEven pnpSelected", 1);
    } else {
        // get id from hash
        id = get_hash();
    }

    if(id) {
        // replace history otherwise we have to press back twice
        set_hash(id + "/" + start + "/" + end + "/" + source);
    }

    // reset reload timer for page
    resetRefresh();

    return false;
}

function move_histou_img(factor) {
    var urlArgs = new Object(toQueryParams(jQuery('#histou_iframe').attr('src')));

    start = urlArgs["from"];
    end   = urlArgs["to"];
    diff  = end - start;

    start = (parseInt(diff * factor) + parseInt(start)) / 1000;
    end   = (parseInt(diff * factor) + parseInt(end))   / 1000;

    return set_histou_img(start, end);
}

/* initialize all buttons */
function init_buttons() {
    jQuery('BUTTON.button').button();

    jQuery('A.report_button').button();
    jQuery('BUTTON.report_button').button();

    jQuery('.save_button').button({
        icons: {primary: 'ui-save-button'}
    });

    jQuery('.right_arrow_button').button({
        icons: {primary: 'ui-r-arrow-button'}
    });

    jQuery('.add_button').button({
        icons: {primary: 'ui-add-button'}
    });

    jQuery('.remove_button').button({
        icons: {primary: 'ui-remove-button'}
    }).click(function() {
        return confirm('really delete?');
    });
}


/*******************************************************************************
88888888888 db  8b           d8 88   ,ad8888ba,   ,ad8888ba,   888b      88
88         d88b `8b         d8' 88  d8"'    `"8b d8"'    `"8b  8888b     88
88        d8'`8b `8b       d8'  88 d8'          d8'        `8b 88 `8b    88
88aaaaa  d8'  `8b `8b     d8'   88 88           88          88 88  `8b   88
88""""" d8YaaaaY8b `8b   d8'    88 88           88          88 88   `8b  88
88     d8""""""""8b `8b d8'     88 Y8,          Y8,        ,8P 88    `8b 88
88    d8'        `8b `888'      88  Y8a.    .a8P Y8a.    .a8P  88     `8888
88   d8'          `8b `8'       88   `"Y8888Y"'   `"Y8888Y"'   88      `888
*******************************************************************************/
/* see https://github.com/antyrat/stackoverflow-favicon-counter for original source */
function updateFaviconCounter(value, color, fill, font, fontColor) {
    var faviconURL = url_prefix + 'themes/' + theme + '/images/favicon.ico';
    var context    = window.parent.frames ? window.parent.document : window.document;
    if(fill == undefined) { fill = true; }
    if(!font)      { font      = "10px Normal Tahoma"; }
    if(!fontColor) { fontColor = "#000000"; }

    var counterValue = null;
    if(jQuery.isNumeric(value)) {
        if(value > 0) {
            counterValue = ( value > 99 ) ? '\u221E' : value;
        }
    } else {
        counterValue = value;
    }

    // breaks on IE8 (and lower)
    try {
        if(counterValue != null) {
            var canvas       = document.createElement("canvas"),
                ctx          = canvas.getContext('2d'),
                faviconImage = new Image();

            canvas.width  = 16;
            canvas.height = 16;

            faviconImage.onload = function() {
                // draw original favicon
                ctx.drawImage(faviconImage, 0, 0);

                // draw counter rectangle holder
                if(fill) {
                    ctx.beginPath();
                    ctx.rect( 5, 6, 16, 10 );
                    ctx.fillStyle = color;
                    ctx.fill();
                }

                // counter font settings
                ctx.font      = font;
                ctx.fillStyle = fontColor;

                // get counter metrics
                var metrics  = ctx.measureText(counterValue );
                counterTextX = ( metrics.width >= 10 ) ? 6 : 9, // detect counter value position

                // draw counter on favicon
                ctx.fillText( counterValue , counterTextX , 15, 16 );

                // append new favicon to document head section
                faviconURL = canvas.toDataURL();
                jQuery('link[rel$=icon]', context).remove();
                jQuery('head', context).append( jQuery('<link rel="shortcut icon" type="image/x-icon" href="' + faviconURL + '"/>' ) );
            }
            faviconImage.src = faviconURL; // create original favicon
        } else {
            // if there is no counter value we draw default favicon
            jQuery('link[rel$=icon]', context).remove();
            jQuery('head', context).append( jQuery('<link rel="shortcut icon" type="image/x-icon" href="' + faviconURL + '"/>' ) );
        }
    } catch(err) { debug(err) }
}

/* save settings in a cookie */
function prefSubmitCounter(url, value) {
  if(value == false) {
      updateFaviconCounter(null);
  }

  cookieSave('thruk_favicon', value);
  // favicon is created from the parent page, so reload that one if we use frames
  try {
    window.parent.location.reload();
  } catch(e) {
    reloadPage();
  }
}


/* handle list wizard dialog */
var available_members = new Array();
var selected_members  = new Array();
var init_tool_list_wizard_initialized = {};
function init_tool_list_wizard(id, type) {
    id = id.substr(0, id.length -3);
    var tmp       = type.split(/,/);
    var input_id  = tmp[0];
    type          = tmp[1];
    var aggregate = Math.abs(tmp[2]);
    var templates = tmp[3] ? true : false;

    var $d = jQuery('#' + id + 'dialog')
      .dialog({
        dialogClass: 'dialogWithDropShadow',
        autoOpen:    false,
        width:       'auto',
        maxWidth:    1024,
        position:    'top',
        close:       function(event, ui) { ajax_search.hide_results(undefined, 1); return true; }
    });

    // initialize selected members
    selected_members   = new Array();
    selected_members_h = new Object();
    var options = [];
    var list = jQuery('#'+input_id).val().split(/\s*,\s*/);
    for(var x=0; x<list.length;x+=aggregate) {
        if(list[x] != '') {
            var val = list[x];
            for(var y=1; y<aggregate;y++) {
                val = val+','+list[x+y]
            }
            selected_members.push(val);
            selected_members_h[val] = 1;
            options.push(new Option(val, val));
        }
    }
    set_select_options(id+"selected_members", options, true);
    sortlist(id+"selected_members");
    reset_original_options(id+"selected_members");

    var strip = true;
    var url = 'status.cgi?format=search&amp;type='+type;
    if(window.location.href.match(/conf.cgi/)) {
        url = 'conf.cgi?action=json&amp;type='+type;
        strip = false;
    }

    // initialize available members
    available_members = new Array();
    jQuery("select#"+id+"available_members").html('<option disabled>loading...<\/option>');
    jQuery.ajax({
        url: url,
        type: 'POST',
        success: function(data) {
            var result = data[0]['data'];
            if(templates) {
                result = data[1]['data'];
            }
            var options = [];
            var size = result.length;
            for(var x=0; x<size;x++) {
                if(strip) {
                    result[x] = result[x].replace(/^(.*)\ \-\ .*/, '$1');
                }
                if(!selected_members_h[result[x]]) {
                    available_members.push(result[x]);
                    options.push(new Option(result[x], result[x]));
                }
            }
            set_select_options(id+"available_members", options, true);
            sortlist(id+"available_members");
            reset_original_options(id+"available_members");
        },
        error: function() {
            jQuery("select#"+id+"available_members").html('<option disabled>error<\/option>');
        }
    });

    // button has to be initialized only once
    if(init_tool_list_wizard_initialized[id] != undefined) {
        // reset filter
        jQuery('INPUT.filter_available').val('');
        jQuery('INPUT.filter_selected').val('');
        data_filter_select(id+'available_members', '');
        data_filter_select(id+'selected_members', '');
        $d.dialog('open');
        return;
    }
    init_tool_list_wizard_initialized[id] = true;

    jQuery('#' + id + 'accept').button({
        icons: {primary: 'ui-ok-button'}
    }).click(function() {
        data_filter_select(id+'available_members', '');
        data_filter_select(id+'selected_members', '');

        var newval = '';
        var lb = document.getElementById(id+"selected_members");
        for(i=0; i<lb.length; i++)  {
            newval += lb.options[i].value;
            if(i < lb.length-1) {
                newval += ',';
            }
        }
        jQuery('#'+input_id).val(newval);
        ajax_search.hide_results(undefined, 1);
        $d.dialog('close');
        return false;
    });

    $d.dialog('open');
    return;
}
/**
 *                                                        ____   _____
 *  Dynarch Calendar -- JSCal2, version 1.9               \  /_  /   /
 *  Built at 2011/03/13 10:28 GMT                          \  / /   /
 *                                                          \/ /_  /
 *  (c) Dynarch.com 2009                                     \  / /
 *  All rights reserved.                                       / /
 *  Visit www.dynarch.com/projects/calendar for details        \/
 *
 */
Calendar=function(){function bm(a){typeof a=="string"&&(a=document.getElementById(a));return a}function bk(a,b,c){for(c=0;c<a.length;++c)b(a[c])}function bj(){var a=document.documentElement,b=document.body;return{x:a.scrollLeft||b.scrollLeft,y:a.scrollTop||b.scrollTop,w:a.clientWidth||window.innerWidth||b.clientWidth,h:a.clientHeight||window.innerHeight||b.clientHeight}}function bi(a){var b=0,c=0,d=/^div$/i.test(a.tagName),e,f;d&&a.scrollLeft&&(b=a.scrollLeft),d&&a.scrollTop&&(c=a.scrollTop),e={x:a.offsetLeft-b,y:a.offsetTop-c},a.offsetParent&&(f=bi(a.offsetParent),e.x+=f.x,e.y+=f.y);return e}function bh(a,b){var c=e?a.clientX+document.body.scrollLeft:a.pageX,d=e?a.clientY+document.body.scrollTop:a.pageY;b&&(c-=b.x,d-=b.y);return{x:c,y:d}}function bg(a,b){var c=a.style;b!=null&&(c.display=b?"":"none");return c.display!="none"}function bf(a,b){b===""?e?a.style.filter="":a.style.opacity="":b!=null?e?a.style.filter="alpha(opacity="+b*100+")":a.style.opacity=b:e?/alpha\(opacity=([0-9.])+\)/.test(a.style.opacity)&&(b=parseFloat(RegExp.$1)/100):b=parseFloat(a.style.opacity);return b}function bd(a,b,c){function h(){var b=a.len;a.onUpdate(c/b,d),c==b&&g(),++c}function g(){b&&(clearInterval(b),b=null),a.onStop(c/a.len,d)}function f(){b&&g(),c=0,b=setInterval(h,1e3/a.fps)}function d(a,b,c,d){return d?c+a*(b-c):b+a*(c-b)}a=U(a,{fps:50,len:15,onUpdate:bl,onStop:bl}),e&&(a.len=Math.round(a.len/2)),f();return{start:f,stop:g,update:h,args:a,map:d}}function bc(a,b){if(!b(a))for(var c=a.firstChild;c;c=c.nextSibling)c.nodeType==1&&bc(c,b)}function bb(a,b){var c=ba(arguments,2);return b==undefined?function(){return a.apply(this,c.concat(ba(arguments)))}:function(){return a.apply(b,c.concat(ba(arguments)))}}function ba(a,b){b==null&&(b=0);var c,d,e;try{c=Array.prototype.slice.call(a,b)}catch(f){c=Array(a.length-b);for(d=b,e=0;d<a.length;++d,++e)c[e]=a[d]}return c}function _(a,b,c){var d=null;document.createElementNS?d=document.createElementNS("http://www.w3.org/1999/xhtml",a):d=document.createElement(a),b&&(d.className=b),c&&c.appendChild(d);return d}function $(a,b,c){if(b instanceof Array)for(var d=b.length;--d>=0;)$(a,b[d],c);else Y(b,c,a?c:null);return a}function Z(a,b){return Y(a,b,b)}function Y(a,b,c){if(a){var d=a.className.replace(/^\s+|\s+$/,"").split(/\x20/),e=[],f;for(f=d.length;f>0;)d[--f]!=b&&e.push(d[f]);c&&e.push(c),a.className=e.join(" ")}return c}function X(a){a=a||window.event,e?(a.cancelBubble=!0,a.returnValue=!1):(a.preventDefault(),a.stopPropagation());return!1}function W(a,b,c,d){if(a instanceof Array)for(var f=a.length;--f>=0;)W(a[f],b,c);else if(typeof b=="object")for(var f in b)b.hasOwnProperty(f)&&W(a,f,b[f],c);else a.removeEventListener?a.removeEventListener(b,c,e?!0:!!d):a.detachEvent?a.detachEvent("on"+b,c):a["on"+b]=null}function V(a,b,c,d){if(a instanceof Array)for(var f=a.length;--f>=0;)V(a[f],b,c,d);else if(typeof b=="object")for(var f in b)b.hasOwnProperty(f)&&V(a,f,b[f],c);else a.addEventListener?a.addEventListener(b,c,e?!0:!!d):a.attachEvent?a.attachEvent("on"+b,c):a["on"+b]=c}function U(a,b,c,d){d={};for(c in b)b.hasOwnProperty(c)&&(d[c]=b[c]);for(c in a)a.hasOwnProperty(c)&&(d[c]=a[c]);return d}function T(a){if(/\S/.test(a)){a=a.toLowerCase();function b(b){for(var c=b.length;--c>=0;)if(b[c].toLowerCase().indexOf(a)==0)return c+1}return b(L("smn"))||b(L("mn"))}}function S(a){if(a){if(typeof a=="number")return P(a);if(!(a instanceof Date)){var b=a.split(/-/);return new Date(parseInt(b[0],10),parseInt(b[1],10)-1,parseInt(b[2],10),12,0,0,0)}}return a}function R(a,b){var c=a.getMonth(),d=a.getDate(),e=a.getFullYear(),f=M(a),g=a.getDay(),h=a.getHours(),i=h>=12,j=i?h-12:h,k=N(a),l=a.getMinutes(),m=a.getSeconds(),n=/%./g,o;j===0&&(j=12),o={"%a":L("sdn")[g],"%A":L("dn")[g],"%b":L("smn")[c],"%B":L("mn")[c],"%C":1+Math.floor(e/100),"%d":d<10?"0"+d:d,"%e":d,"%H":h<10?"0"+h:h,"%I":j<10?"0"+j:j,"%j":k<10?"00"+k:k<100?"0"+k:k,"%k":h,"%l":j,"%m":c<9?"0"+(1+c):1+c,"%o":1+c,"%M":l<10?"0"+l:l,"%n":"\n","%p":i?"PM":"AM","%P":i?"pm":"am","%s":Math.floor(a.getTime()/1e3),"%S":m<10?"0"+m:m,"%t":"\t","%U":f<10?"0"+f:f,"%W":f<10?"0"+f:f,"%V":f<10?"0"+f:f,"%u":g+1,"%w":g,"%y":(""+e).substr(2,2),"%Y":e,"%%":"%"};return b.replace(n,function(a){return o.hasOwnProperty(a)?o[a]:a})}function Q(a,b,c){var d=a.getFullYear(),e=a.getMonth(),f=a.getDate(),g=b.getFullYear(),h=b.getMonth(),i=b.getDate();return d<g?-3:d>g?3:e<h?-2:e>h?2:c?0:f<i?-1:f>i?1:0}function P(a,b,c,d,e){if(!(a instanceof Date)){a=parseInt(a,10);var f=Math.floor(a/1e4);a=a%1e4;var g=Math.floor(a/100);a=a%100,a=new Date(f,g-1,a,b==null?12:b,c==null?0:c,d==null?0:d,e==null?0:e)}return a}function O(a){if(a instanceof Date)return 1e4*a.getFullYear()+100*(a.getMonth()+1)+a.getDate();if(typeof a=="string")return parseInt(a,10);return a}function N(a){a=new Date(a.getFullYear(),a.getMonth(),a.getDate(),12,0,0);var b=new Date(a.getFullYear(),0,1,12,0,0),c=a-b;return Math.floor(c/864e5)}function M(a){a=new Date(a.getFullYear(),a.getMonth(),a.getDate(),12,0,0);var b=a.getDay();a.setDate(a.getDate()-(b+6)%7+3);var c=a.valueOf();a.setMonth(0),a.setDate(4);return Math.round((c-a.valueOf())/6048e5)+1}function L(a,b){var c=i.__.data[a];b&&typeof c=="string"&&(c=K(c,b));return c}function K(a,b){return a.replace(/\$\{([^:\}]+)(:[^\}]+)?\}/g,function(a,c,d){var e=b[c],f;d&&(f=d.substr(1).split(/\s*\|\s*/),e=(e>=f.length?f[f.length-1]:f[e]).replace(/##?/g,function(a){return a.length==2?"#":e}));return e})}function J(b){if(!this._menuAnim){b=b||window.event;var c=b.target||b.srcElement,d=c.getAttribute("dyc-btn"),e=b.keyCode,f=b.charCode||e,g=H[e];if("year"==d&&e==13){var h=new Date(this.date);h.setDate(1),h.setFullYear(this._getInputYear()),this.moveTo(h,!0),z(this,!1);return X(b)}if(this._menuVisible){if(e==27){z(this,!1);return X(b)}}else{b.ctrlKey||(g=null),g==null&&!b.ctrlKey&&(g=I[e]),e==36&&(g=0);if(g!=null){y(this,g);return X(b)}f=String.fromCharCode(f).toLowerCase();var i=this.els.yearInput,j=this.selection;if(f==" "){z(this,!0),this.focus(),i.focus(),i.select();return X(b)}if(f>="0"&&f<="9"){z(this,!0),this.focus(),i.value=f,i.focus();return X(b)}var k=L("mn"),l=b.shiftKey?-1:this.date.getMonth(),m=0,n;while(++m<12){n=k[(l+m)%12].toLowerCase();if(n.indexOf(f)==0){var h=new Date(this.date);h.setDate(1),h.setMonth((l+m)%12),this.moveTo(h,!0);return X(b)}}if(e>=37&&e<=40){var h=this._lastHoverDate;if(!h&&!j.isEmpty()){h=e<39?j.getFirstDate():j.getLastDate();if(h<this._firstDateVisible||h>this._lastDateVisible)h=null}if(!h)h=e<39?this._lastDateVisible:this._firstDateVisible;else{var o=h;h=P(h);var l=100;while(l-->0){switch(e){case 37:h.setDate(h.getDate()-1);break;case 38:h.setDate(h.getDate()-7);break;case 39:h.setDate(h.getDate()+1);break;case 40:h.setDate(h.getDate()+7)}if(!this.isDisabled(h))break}h=O(h),(h<this._firstDateVisible||h>this._lastDateVisible)&&this.moveTo(h)}Y(this._getDateDiv(o),Z(this._getDateDiv(h),"DynarchCalendar-hover-date")),this._lastHoverDate=h;return X(b)}if(e==13&&this._lastHoverDate){j.type==a.SEL_MULTIPLE&&(b.shiftKey||b.ctrlKey)?(b.shiftKey&&this._selRangeStart&&(j.clear(!0),j.selectRange(this._selRangeStart,this._lastHoverDate)),b.ctrlKey&&j.set(this._selRangeStart=this._lastHoverDate,!0)):j.reset(this._selRangeStart=this._lastHoverDate);return X(b)}e==27&&!this.args.cont&&this.hide()}}}function G(){this.refresh();var a=this.inputField,b=this.selection;if(a){var c=b.print(this.dateFormat);/input|textarea/i.test(a.tagName)?a.value=c:a.innerHTML=c}this.callHooks("onSelect",this,b)}function F(a){a=a||window.event;var b=C(a);if(b){var c=b.getAttribute("dyc-btn"),d=b.getAttribute("dyc-type"),e=a.wheelDelta?a.wheelDelta/120:-a.detail/3;e=e<0?-1:e>0?1:0,this.args.reverseWheel&&(e=-e);if(/^(time-(hour|min))/.test(d)){switch(RegExp.$1){case"time-hour":this.setHours(this.getHours()+e);break;case"time-min":this.setMinutes(this.getMinutes()+this.args.minuteStep*e)}X(a)}else/Y/i.test(c)&&(e*=2),y(this,-e),X(a)}}function E(a,b){b=b||window.event;var c=C(b);if(c){var d=c.getAttribute("dyc-type");if(d&&!c.getAttribute("disabled"))if(!a||!this._bodyAnim||d!="date"){var e=c.getAttribute("dyc-cls");e=e?D(e,0):"DynarchCalendar-hover-"+d,(d!="date"||this.selection.type)&&$(a,c,e),d=="date"&&($(a,c.parentNode.parentNode,"DynarchCalendar-hover-week"),this._showTooltip(c.getAttribute("dyc-date"))),/^time-hour/.test(d)&&$(a,this.els.timeHour,"DynarchCalendar-hover-time"),/^time-min/.test(d)&&$(a,this.els.timeMinute,"DynarchCalendar-hover-time"),Y(this._getDateDiv(this._lastHoverDate),"DynarchCalendar-hover-date"),this._lastHoverDate=null}}a||this._showTooltip()}function D(a,b){return"DynarchCalendar-"+a.split(/,/)[b]}function C(a){var b=a.target||a.srcElement,c=b;while(b&&b.getAttribute&&!b.getAttribute("dyc-type"))b=b.parentNode;return b.getAttribute&&b||c}function B(a){a=a||window.event;var b=this.els.topCont.style,c=bh(a,this._mouseDiff);b.left=c.x+"px",b.top=c.y+"px"}function A(b,c){c=c||window.event;var d=C(c);if(d&&!d.getAttribute("disabled")){var f=d.getAttribute("dyc-btn"),g=d.getAttribute("dyc-type"),h=d.getAttribute("dyc-date"),i=this.selection,j,k={mouseover:X,mousemove:X,mouseup:function(a){var b=d.getAttribute("dyc-cls");b&&Y(d,D(b,1)),clearTimeout(j),W(document,k,!0),k=null}};if(b){setTimeout(bb(this.focus,this),1);var l=d.getAttribute("dyc-cls");l&&Z(d,D(l,1));if("menu"==f)this.toggleMenu();else if(d&&/^[+-][MY]$/.test(f))if(y(this,f)){var m=bb(function(){y(this,f,!0)?j=setTimeout(m,40):(k.mouseup(),y(this,f))},this);j=setTimeout(m,350),V(document,k,!0)}else k.mouseup();else if("year"==f)this.els.yearInput.focus(),this.els.yearInput.select();else if(g=="time-am")V(document,k,!0);else if(/^time/.test(g)){var m=bb(function(a){w.call(this,a),j=setTimeout(m,100)},this,g);w.call(this,g),j=setTimeout(m,350),V(document,k,!0)}else h&&i.type&&(i.type==a.SEL_MULTIPLE?c.shiftKey&&this._selRangeStart?i.selectRange(this._selRangeStart,h):(!c.ctrlKey&&!i.isSelected(h)&&i.clear(!0),i.set(h,!0),this._selRangeStart=h):(i.set(h),this.moveTo(P(h),2)),d=this._getDateDiv(h),E.call(this,!0,{target:d})),V(document,k,!0);e&&k&&/dbl/i.test(c.type)&&k.mouseup(),!this.args.fixed&&/^(DynarchCalendar-(topBar|bottomBar|weekend|weekNumber|menu(-sep)?))?$/.test(d.className)&&!this.args.cont&&(k.mousemove=bb(B,this),this._mouseDiff=bh(c,bi(this.els.topCont)),V(document,k,!0))}else if("today"==f)!this._menuVisible&&i.type==a.SEL_SINGLE&&i.set(new Date),this.moveTo(new Date,!0),z(this,!1);else if(/^m([0-9]+)/.test(f)){var h=new Date(this.date);h.setDate(1),h.setMonth(RegExp.$1),h.setFullYear(this._getInputYear()),this.moveTo(h,!0),z(this,!1)}else g=="time-am"&&this.setHours(this.getHours()+12);e||X(c)}}function z(a,b){a._menuVisible=b,$(b,a.els.title,"DynarchCalendar-pressed-title");var c=a.els.menu;f&&(c.style.height=a.els.main.offsetHeight+"px");if(!a.args.animation)bg(c,b),a.focused&&a.focus();else{a._menuAnim&&a._menuAnim.stop();var d=a.els.main.offsetHeight;f&&(c.style.width=a.els.topBar.offsetWidth+"px"),b&&(c.firstChild.style.marginTop=-d+"px",a.args.opacity>0&&bf(c,0),bg(c,!0)),a._menuAnim=bd({onUpdate:function(e,f){c.firstChild.style.marginTop=f(be.accel_b(e),-d,0,!b)+"px",a.args.opacity>0&&bf(c,f(be.accel_b(e),0,.85,!b))},onStop:function(){a.args.opacity>0&&bf(c,.85),c.firstChild.style.marginTop="",a._menuAnim=null,b||(bg(c,!1),a.focused&&a.focus())}})}}function y(a,b,c){this._bodyAnim&&this._bodyAnim.stop();var d;if(b!=0){d=new Date(a.date),d.setDate(1);switch(b){case"-Y":case-2:d.setFullYear(d.getFullYear()-1);break;case"+Y":case 2:d.setFullYear(d.getFullYear()+1);break;case"-M":case-1:d.setMonth(d.getMonth()-1);break;case"+M":case 1:d.setMonth(d.getMonth()+1)}}else d=new Date;return a.moveTo(d,!c)}function w(a){switch(a){case"time-hour+":this.setHours(this.getHours()+1);break;case"time-hour-":this.setHours(this.getHours()-1);break;case"time-min+":this.setMinutes(this.getMinutes()+this.args.minuteStep);break;case"time-min-":this.setMinutes(this.getMinutes()-this.args.minuteStep);break;default:return}}function v(){this._bluringTimeout=setTimeout(bb(u,this),50)}function u(){this.focused=!1,Y(this.els.main,"DynarchCalendar-focused"),this._menuVisible&&z(this,!1),this.args.cont||this.hide(),this.callHooks("onBlur",this)}function t(){this._bluringTimeout&&clearTimeout(this._bluringTimeout),this.focused=!0,Z(this.els.main,"DynarchCalendar-focused"),this.callHooks("onFocus",this)}function s(a){var b=_("div"),c=a.els={},d={mousedown:bb(A,a,!0),mouseup:bb(A,a,!1),mouseover:bb(E,a,!0),mouseout:bb(E,a,!1),keypress:bb(J,a)};a.args.noScroll||(d[g?"DOMMouseScroll":"mousewheel"]=bb(F,a)),e&&(d.dblclick=d.mousedown,d.keydown=d.keypress),b.innerHTML=m(a),bc(b.firstChild,function(a){var b=r[a.className];b&&(c[b]=a),e&&a.setAttribute("unselectable","on")}),V(c.main,d),V([c.focusLink,c.yearInput],a._focusEvents={focus:bb(t,a),blur:bb(v,a)}),a.moveTo(a.date,!1),a.setTime(null,!0);return c.topCont}function q(a){function d(){c.showTime&&(b.push("<td>"),p(a,b),b.push("</td>"))}var b=[],c=a.args;b.push("<table",j," style='width:100%'><tr>"),c.timePos=="left"&&d(),c.bottomBar&&(b.push("<td>"),b.push("<table",j,"><tr><td>","<div dyc-btn='today' dyc-cls='hover-bottomBar-today,pressed-bottomBar-today' dyc-type='bottomBar-today' ","class='DynarchCalendar-bottomBar-today'>",L("today"),"</div>","</td></tr></table>"),b.push("</td>")),c.timePos=="right"&&d(),b.push("</tr></table>");return b.join("")}function p(a,b){b.push("<table class='DynarchCalendar-time'"+j+"><tr>","<td rowspan='2'><div dyc-type='time-hour' dyc-cls='hover-time,pressed-time' class='DynarchCalendar-time-hour'></div></td>","<td dyc-type='time-hour+' dyc-cls='hover-time,pressed-time' class='DynarchCalendar-time-up'></td>","<td rowspan='2' class='DynarchCalendar-time-sep'></td>","<td rowspan='2'><div dyc-type='time-min' dyc-cls='hover-time,pressed-time' class='DynarchCalendar-time-minute'></div></td>","<td dyc-type='time-min+' dyc-cls='hover-time,pressed-time' class='DynarchCalendar-time-up'></td>"),a.args.showTime==12&&b.push("<td rowspan='2' class='DynarchCalendar-time-sep'></td>","<td rowspan='2'><div class='DynarchCalendar-time-am' dyc-type='time-am' dyc-cls='hover-time,pressed-time'></div></td>"),b.push("</tr><tr>","<td dyc-type='time-hour-' dyc-cls='hover-time,pressed-time' class='DynarchCalendar-time-down'></td>","<td dyc-type='time-min-' dyc-cls='hover-time,pressed-time' class='DynarchCalendar-time-down'></td>","</tr></table>")}function o(a){var b=["<table height='100%'",j,"><tr><td>","<table style='margin-top: 1.5em'",j,">","<tr><td colspan='3'><input dyc-btn='year' class='DynarchCalendar-menu-year' size='6' value='",a.date.getFullYear(),"' /></td></tr>","<tr><td><div dyc-type='menubtn' dyc-cls='hover-navBtn,pressed-navBtn' dyc-btn='today'>",L("goToday"),"</div></td></tr>","</table>","<p class='DynarchCalendar-menu-sep'>&nbsp;</p>","<table class='DynarchCalendar-menu-mtable'",j,">"],c=L("smn"),d=0,e=b.length,f;while(d<12){b[e++]="<tr>";for(f=4;--f>0;)b[e++]="<td><div dyc-type='menubtn' dyc-cls='hover-navBtn,pressed-navBtn' dyc-btn='m"+d+"' class='DynarchCalendar-menu-month'>"+c[d++]+"</div></td>";b[e++]="</tr>"}b[e++]="</table></td></tr></table>";return b.join("")}function n(a){return"<div unselectable='on'>"+R(a.date,a.args.titleFormat)+"</div>"}function m(a){var b=["<table class='DynarchCalendar-topCont'",j,"><tr><td>","<div class='DynarchCalendar'>",e?"<a class='DynarchCalendar-focusLink' href='#'></a>":"<button class='DynarchCalendar-focusLink'></button>","<div class='DynarchCalendar-topBar'>","<div dyc-type='nav' dyc-btn='-Y' dyc-cls='hover-navBtn,pressed-navBtn' ","class='DynarchCalendar-navBtn DynarchCalendar-prevYear'><div></div></div>","<div dyc-type='nav' dyc-btn='+Y' dyc-cls='hover-navBtn,pressed-navBtn' ","class='DynarchCalendar-navBtn DynarchCalendar-nextYear'><div></div></div>","<div dyc-type='nav' dyc-btn='-M' dyc-cls='hover-navBtn,pressed-navBtn' ","class='DynarchCalendar-navBtn DynarchCalendar-prevMonth'><div></div></div>","<div dyc-type='nav' dyc-btn='+M' dyc-cls='hover-navBtn,pressed-navBtn' ","class='DynarchCalendar-navBtn DynarchCalendar-nextMonth'><div></div></div>","<table class='DynarchCalendar-titleCont'",j,"><tr><td>","<div dyc-type='title' dyc-btn='menu' dyc-cls='hover-title,pressed-title' class='DynarchCalendar-title'>",n(a),"</div></td></tr></table>","<div class='DynarchCalendar-dayNames'>",k(a),"</div>","</div>","<div class='DynarchCalendar-body'></div>"];(a.args.bottomBar||a.args.showTime)&&b.push("<div class='DynarchCalendar-bottomBar'>",q(a),"</div>"),b.push("<div class='DynarchCalendar-menu' style='display: none'>",o(a),"</div>","<div class='DynarchCalendar-tooltip'></div>","</div>","</td></tr></table>");return b.join("")}function l(a,b,c){b=b||a.date,c=c||a.fdow,b=new Date(b.getFullYear(),b.getMonth(),b.getDate(),12,0,0,0);var d=b.getMonth(),e=[],f=0,g=a.args.weekNumbers;b.setDate(1);var h=(b.getDay()-c)%7;h<0&&(h+=7),b.setDate(0-h),b.setDate(b.getDate()+1);var i=new Date,k=i.getDate(),l=i.getMonth(),m=i.getFullYear();e[f++]="<table class='DynarchCalendar-bodyTable'"+j+">";for(var n=0;n<6;++n){e[f++]="<tr class='DynarchCalendar-week",n==0&&(e[f++]=" DynarchCalendar-first-row"),n==5&&(e[f++]=" DynarchCalendar-last-row"),e[f++]="'>",g&&(e[f++]="<td class='DynarchCalendar-first-col'><div class='DynarchCalendar-weekNumber'>"+M(b)+"</div></td>");for(var o=0;o<7;++o){var p=b.getDate(),q=b.getMonth(),r=b.getFullYear(),s=1e4*r+100*(q+1)+p,t=a.selection.isSelected(s),u=a.isDisabled(b);e[f++]="<td class='",o==0&&!g&&(e[f++]=" DynarchCalendar-first-col"),o==0&&n==0&&(a._firstDateVisible=s),o==6&&(e[f++]=" DynarchCalendar-last-col",n==5&&(a._lastDateVisible=s)),t&&(e[f++]=" DynarchCalendar-td-selected"),e[f++]="'><div dyc-type='date' unselectable='on' dyc-date='"+s+"' ",u&&(e[f++]="disabled='1' "),e[f++]="class='DynarchCalendar-day",L("weekend").indexOf(b.getDay())>=0&&(e[f++]=" DynarchCalendar-weekend"),q!=d&&(e[f++]=" DynarchCalendar-day-othermonth"),p==k&&q==l&&r==m&&(e[f++]=" DynarchCalendar-day-today"),u&&(e[f++]=" DynarchCalendar-day-disabled"),t&&(e[f++]=" DynarchCalendar-day-selected"),u=a.args.dateInfo(b),u&&u.klass&&(e[f++]=" "+u.klass),e[f++]="'>"+p+"</div></td>",b=new Date(r,q,p+1,12,0,0,0)}e[f++]="</tr>"}e[f++]="</table>";return e.join("")}function k(a){var b=["<table",j,"><tr>"],c=0;a.args.weekNumbers&&b.push("<td><div class='DynarchCalendar-weekNumber'>",L("wk"),"</div></td>");while(c<7){var d=(c++ +a.fdow)%7;b.push("<td><div",L("weekend").indexOf(d)>=0?" class='DynarchCalendar-weekend'>":">",L("sdn")[d],"</div></td>")}b.push("</tr></table>");return b.join("")}function a(b){b=b||{},this.args=b=U(b,{animation:!f,cont:null,bottomBar:!0,date:!0,fdow:L("fdow"),min:null,max:null,reverseWheel:!1,selection:[],selectionType:a.SEL_SINGLE,weekNumbers:!1,align:"Bl/ / /T/r",inputField:null,trigger:null,dateFormat:"%Y-%m-%d",fixed:!1,opacity:e?1:3,titleFormat:"%b %Y",showTime:!1,timePos:"right",time:!0,minuteStep:5,noScroll:!1,disabled:bl,checkRange:!1,dateInfo:bl,onChange:bl,onSelect:bl,onTimeChange:bl,onFocus:bl,onBlur:bl}),this.handlers={};var c=this,d=new Date;b.min=S(b.min),b.max=S(b.max),b.date===!0&&(b.date=d),b.time===!0&&(b.time=d.getHours()*100+Math.floor(d.getMinutes()/b.minuteStep)*b.minuteStep),this.date=S(b.date),this.time=b.time,this.fdow=b.fdow,bk("onChange onSelect onTimeChange onFocus onBlur".split(/\s+/),function(a){var d=b[a];d instanceof Array||(d=[d]),c.handlers[a]=d}),this.selection=new a.Selection(b.selection,b.selectionType,G,this);var g=s(this);b.cont&&bm(b.cont).appendChild(g),b.trigger&&this.manageFields(b.trigger,b.inputField,b.dateFormat)}var b=navigator.userAgent,c=/opera/i.test(b),d=/Konqueror|Safari|KHTML/i.test(b),e=/msie/i.test(b)&&!c&&!/mac_powerpc/i.test(b),f=e&&/msie 6/i.test(b),g=/gecko/i.test(b)&&!d&&!c&&!e,h=a.prototype,i=a.I18N={};a.SEL_NONE=0,a.SEL_SINGLE=1,a.SEL_MULTIPLE=2,a.SEL_WEEK=3,a.dateToInt=O,a.intToDate=P,a.printDate=R,a.formatString=K,a.i18n=L,a.LANG=function(a,b,c){i.__=i[a]={name:b,data:c}},a.setup=function(b){return new a(b)},h.moveTo=function(a,b){var c=this;a=S(a);var d=Q(a,c.date,!0),e,f=c.args,g=f.min&&Q(a,f.min),h=f.max&&Q(a,f.max);f.animation||(b=!1),$(g!=null&&g<=1,[c.els.navPrevMonth,c.els.navPrevYear],"DynarchCalendar-navDisabled"),$(h!=null&&h>=-1,[c.els.navNextMonth,c.els.navNextYear],"DynarchCalendar-navDisabled"),g<-1&&(a=f.min,e=1,d=0),h>1&&(a=f.max,e=2,d=0),c.date=a,c.refresh(!!b),c.callHooks("onChange",c,a,b);if(b&&(d!=0||b!=2)){c._bodyAnim&&c._bodyAnim.stop();var i=c.els.body,j=_("div","DynarchCalendar-animBody-"+x[d],i),k=i.firstChild,m=bf(k)||.7,n=e?be.brakes:d==0?be.shake:be.accel_ab2,o=d*d>4,p=o?k.offsetTop:k.offsetLeft,q=j.style,r=o?i.offsetHeight:i.offsetWidth;d<0?r+=p:d>0?r=p-r:(r=Math.round(r/7),e==2&&(r=-r));if(!e&&d!=0){var s=j.cloneNode(!0),t=s.style,u=2*r;s.appendChild(k.cloneNode(!0)),t[o?"marginTop":"marginLeft"]=r+"px",i.appendChild(s)}k.style.visibility="hidden",j.innerHTML=l(c),c._bodyAnim=bd({onUpdate:function(a,b){var f=n(a);if(s)var g=b(f,r,u)+"px";if(e)q[o?"marginTop":"marginLeft"]=b(f,r,0)+"px";else{if(o||d==0)q.marginTop=b(d==0?n(a*a):f,0,r)+"px",d!=0&&(t.marginTop=g);if(!o||d==0)q.marginLeft=b(f,0,r)+"px",d!=0&&(t.marginLeft=g)}c.args.opacity>2&&s&&(bf(s,1-f),bf(j,f))},onStop:function(b){i.innerHTML=l(c,a),c._bodyAnim=null}})}c._lastHoverDate=null;return g>=-1&&h<=1},h.isDisabled=function(a){var b=this.args;return b.min&&Q(a,b.min)<0||b.max&&Q(a,b.max)>0||b.disabled(a)},h.toggleMenu=function(){z(this,!this._menuVisible)},h.refresh=function(a){var b=this.els;a||(b.body.innerHTML=l(this)),b.title.innerHTML=n(this),b.yearInput.value=this.date.getFullYear()},h.redraw=function(){var a=this,b=a.els;a.refresh(),b.dayNames.innerHTML=k(a),b.menu.innerHTML=o(a),b.bottomBar&&(b.bottomBar.innerHTML=q(a)),bc(b.topCont,function(c){var d=r[c.className];d&&(b[d]=c),c.className=="DynarchCalendar-menu-year"?(V(c,a._focusEvents),b.yearInput=c):e&&c.setAttribute("unselectable","on")}),a.setTime(null,!0)},h.setLanguage=function(b){var c=a.setLanguage(b);c&&(this.fdow=c.data.fdow,this.redraw())},a.setLanguage=function(a){var b=i[a];b&&(i.__=b);return b},h.focus=function(){try{this.els[this._menuVisible?"yearInput":"focusLink"].focus()}catch(a){}t.call(this)},h.blur=function(){this.els.focusLink.blur(),this.els.yearInput.blur(),u.call(this)},h.showAt=function(a,b,c){this._showAnim&&this._showAnim.stop(),c=c&&this.args.animation;var d=this.els.topCont,e=this,f=this.els.body.firstChild,g=f.offsetHeight,h=d.style;h.position="absolute",h.left=a+"px",h.top=b+"px",h.zIndex=1e4,h.display="",c&&(f.style.marginTop=-g+"px",this.args.opacity>1&&bf(d,0),this._showAnim=bd({onUpdate:function(a,b){f.style.marginTop=-b(be.accel_b(a),g,0)+"px",e.args.opacity>1&&bf(d,a)},onStop:function(){e.args.opacity>1&&bf(d,""),e._showAnim=null}}))},h.hide=function(){var a=this.els.topCont,b=this,c=this.els.body.firstChild,d=c.offsetHeight,e=bi(a).y;this.args.animation?(this._showAnim&&this._showAnim.stop(),this._showAnim=bd({onUpdate:function(f,g){b.args.opacity>1&&bf(a,1-f),c.style.marginTop=-g(be.accel_b(f),0,d)+"px",a.style.top=g(be.accel_ab(f),e,e-10)+"px"},onStop:function(){a.style.display="none",c.style.marginTop="",b.args.opacity>1&&bf(a,""),b._showAnim=null}})):a.style.display="none",this.inputField=null},h.popup=function(a,b){function h(b){var c={x:i.x,y:i.y};if(!b)return c;/B/.test(b)&&(c.y+=a.offsetHeight),/b/.test(b)&&(c.y+=a.offsetHeight-f.y),/T/.test(b)&&(c.y-=f.y),/l/.test(b)&&(c.x-=f.x-a.offsetWidth),/L/.test(b)&&(c.x-=f.x),/R/.test(b)&&(c.x+=a.offsetWidth),/c/i.test(b)&&(c.x+=(a.offsetWidth-f.x)/2),/m/i.test(b)&&(c.y+=(a.offsetHeight-f.y)/2);return c}a=bm(a),b||(b=this.args.align),b=b.split(/\x2f/);var c=bi(a),d=this.els.topCont,e=d.style,f,g=bj();e.visibility="hidden",e.display="",this.showAt(0,0),document.body.appendChild(d),f={x:d.offsetWidth,y:d.offsetHeight};var i=c;i=h(b[0]),i.y<g.y&&(i.y=c.y,i=h(b[1])),i.x+f.x>g.x+g.w&&(i.x=c.x,i=h(b[2])),i.y+f.y>g.y+g.h&&(i.y=c.y,i=h(b[3])),i.x<g.x&&(i.x=c.x,i=h(b[4])),this.showAt(i.x,i.y,!0),e.visibility="",this.focus()},h.manageFields=function(b,c,d){var e=this;c=bm(c),b=bm(b),/^button$/i.test(b.tagName)&&b.setAttribute("type","button"),V(b,"click",function(){e.inputField=c,e.dateFormat=d;if(e.selection.type==a.SEL_SINGLE){var f,g,h,i;f=/input|textarea/i.test(c.tagName)?c.value:c.innerText||c.textContent,f&&(g=/(^|[^%])%[bBmo]/.exec(d),h=/(^|[^%])%[de]/.exec(d),g&&h&&(i=g.index<h.index),f=Calendar.parseDate(f,i),f&&(e.selection.set(f,!1,!0),e.args.showTime&&(e.setHours(f.getHours()),e.setMinutes(f.getMinutes())),e.moveTo(f)))}e.popup(b)})},h.callHooks=function(a){var b=ba(arguments,1),c=this.handlers[a],d=0;for(;d<c.length;++d)c[d].apply(this,b)},h.addEventListener=function(a,b){this.handlers[a].push(b)},h.removeEventListener=function(a,b){var c=this.handlers[a],d=c.length;while(--d>=0)c[d]===b&&c.splice(d,1)},h.getTime=function(){return this.time},h.setTime=function(a,b){if(this.args.showTime){a=a!=null?a:this.time,this.time=a;var c=this.getHours(),d=this.getMinutes(),e=c<12;this.args.showTime==12&&(c==0&&(c=12),c>12&&(c-=12),this.els.timeAM.innerHTML=L(e?"AM":"PM")),c<10&&(c="0"+c),d<10&&(d="0"+d),this.els.timeHour.innerHTML=c,this.els.timeMinute.innerHTML=d,b||this.callHooks("onTimeChange",this,a)}},h.getHours=function(){return Math.floor(this.time/100)},h.getMinutes=function(){return this.time%100},h.setHours=function(a){a<0&&(a+=24),this.setTime(100*(a%24)+this.time%100)},h.setMinutes=function(a){a<0&&(a+=60),a=Math.floor(a/this.args.minuteStep)*this.args.minuteStep,this.setTime(100*this.getHours()+a%60)},h._getInputYear=function(){var a=parseInt(this.els.yearInput.value,10);isNaN(a)&&(a=this.date.getFullYear());return a},h._showTooltip=function(a){var b="",c,d=this.els.tooltip;a&&(a=P(a),c=this.args.dateInfo(a),c&&c.tooltip&&(b="<div class='DynarchCalendar-tooltipCont'>"+R(a,c.tooltip)+"</div>")),d.innerHTML=b};var j=" align='center' cellspacing='0' cellpadding='0'",r={"DynarchCalendar-topCont":"topCont","DynarchCalendar-focusLink":"focusLink",DynarchCalendar:"main","DynarchCalendar-topBar":"topBar","DynarchCalendar-title":"title","DynarchCalendar-dayNames":"dayNames","DynarchCalendar-body":"body","DynarchCalendar-menu":"menu","DynarchCalendar-menu-year":"yearInput","DynarchCalendar-bottomBar":"bottomBar","DynarchCalendar-tooltip":"tooltip","DynarchCalendar-time-hour":"timeHour","DynarchCalendar-time-minute":"timeMinute","DynarchCalendar-time-am":"timeAM","DynarchCalendar-navBtn DynarchCalendar-prevYear":"navPrevYear","DynarchCalendar-navBtn DynarchCalendar-nextYear":"navNextYear","DynarchCalendar-navBtn DynarchCalendar-prevMonth":"navPrevMonth","DynarchCalendar-navBtn DynarchCalendar-nextMonth":"navNextMonth"},x={"-3":"backYear","-2":"back",0:"now",2:"fwd",3:"fwdYear"},H={37:-1,38:-2,39:1,40:2},I={33:-1,34:1};h._getDateDiv=function(a){var b=null;if(a)try{bc(this.els.body,function(c){if(c.getAttribute("dyc-date")==a)throw b=c})}catch(c){}return b},(a.Selection=function(a,b,c,d){this.type=b,this.sel=a instanceof Array?a:[a],this.onChange=bb(c,d),this.cal=d}).prototype={get:function(){return this.type==a.SEL_SINGLE?this.sel[0]:this.sel},isEmpty:function(){return this.sel.length==0},set:function(b,c,d){var e=this.type==a.SEL_SINGLE;b instanceof Array?(this.sel=b,this.normalize(),d||this.onChange(this)):(b=O(b),e||!this.isSelected(b)?(e?this.sel=[b]:this.sel.splice(this.findInsertPos(b),0,b),this.normalize(),d||this.onChange(this)):c&&this.unselect(b,d))},reset:function(){this.sel=[],this.set.apply(this,arguments)},countDays:function(){var a=0,b=this.sel,c=b.length,d,e,f;while(--c>=0)d=b[c],d instanceof Array&&(e=P(d[0]),f=P(d[1]),a+=Math.round(Math.abs(f.getTime()-e.getTime())/864e5)),++a;return a},unselect:function(a,b){a=O(a);var c=!1;for(var d=this.sel,e=d.length,f;--e>=0;){f=d[e];if(f instanceof Array){if(a>=f[0]&&a<=f[1]){var g=P(a),h=g.getDate();if(a==f[0])g.setDate(h+1),f[0]=O(g),c=!0;else if(a==f[1])g.setDate(h-1),f[1]=O(g),c=!0;else{var i=new Date(g);i.setDate(h+1),g.setDate(h-1),d.splice(e+1,0,[O(i),f[1]]),f[1]=O(g),c=!0}}}else a==f&&(d.splice(e,1),c=!0)}c&&(this.normalize(),b||this.onChange(this))},normalize:function(){this.sel=this.sel.sort(function(a,b){a instanceof Array&&(a=a[0]),b instanceof Array&&(b=b[0]);return a-b});for(var a=this.sel,b=a.length,c,d;--b>=0;){c=a[b];if(c instanceof Array){if(c[0]>c[1]){a.splice(b,1);continue}c[0]==c[1]&&(c=a[b]=c[0])}if(d){var e=d,f=c instanceof Array?c[1]:c;f=P(f),f.setDate(f.getDate()+1),f=O(f);if(f>=e){var g=a[b+1];c instanceof Array&&g instanceof Array?(c[1]=g[1],a.splice(b+1,1)):c instanceof Array?(c[1]=d,a.splice(b+1,1)):g instanceof Array?(g[0]=c,a.splice(b,1)):(a[b]=[c,g],a.splice(b+1,1))}}d=c instanceof Array?c[0]:c}},findInsertPos:function(a){for(var b=this.sel,c=b.length,d;--c>=0;){d=b[c],d instanceof Array&&(d=d[0]);if(d<=a)break}return c+1},clear:function(a){this.sel=[],a||this.onChange(this)},selectRange:function(b,c){b=O(b),c=O(c);if(b>c){var d=b;b=c,c=d}var e=this.cal.args.checkRange;if(!e)return this._do_selectRange(b,c);try{bk((new a.Selection([[b,c]],a.SEL_MULTIPLE,bl)).getDates(),bb(function(a){if(this.isDisabled(a)){e instanceof Function&&e(a,this);throw"OUT"}},this.cal)),this._do_selectRange(b,c)}catch(f){}},_do_selectRange:function(a,b){this.sel.push([a,b]),this.normalize(),this.onChange(this)},isSelected:function(a){for(var b=this.sel.length,c;--b>=0;){c=this.sel[b];if(c instanceof Array&&a>=c[0]&&a<=c[1]||a==c)return!0}return!1},getFirstDate:function(){var a=this.sel[0];a&&a instanceof Array&&(a=a[0]);return a},getLastDate:function(){if(this.sel.length>0){var a=this.sel[this.sel.length-1];a&&a instanceof Array&&(a=a[1]);return a}},print:function(a,b){var c=[],d=0,e,f=this.cal.getHours(),g=this.cal.getMinutes();b||(b=" -> ");while(d<this.sel.length)e=this.sel[d++],e instanceof Array?c.push(R(P(e[0],f,g),a)+b+R(P(e[1],f,g),a)):c.push(R(P(e,f,g),a));return c},getDates:function(a){var b=[],c=0,d,e;while(c<this.sel.length){e=this.sel[c++];if(e instanceof Array){d=P(e[0]),e=e[1];while(O(d)<e)b.push(a?R(d,a):new Date(d)),d.setDate(d.getDate()+1)}else d=P(e);b.push(a?R(d,a):d)}return b}},a.isUnicodeLetter=function(a){return a.toUpperCase()!=a.toLowerCase()},a.parseDate=function(b,c,d){if(!/\S/.test(b))return"";b=b.replace(/^\s+/,"").replace(/\s+$/,""),d=d||new Date;var e=null,f=null,g=null,h=null,i=null,j=null,k=b.match(/([0-9]{1,2}):([0-9]{1,2})(:[0-9]{1,2})?\s*(am|pm)?/i);k&&(h=parseInt(k[1],10),i=parseInt(k[2],10),j=k[3]?parseInt(k[3].substr(1),10):0,b=b.substring(0,k.index)+b.substr(k.index+k[0].length),k[4]&&(k[4].toLowerCase()=="pm"&&h<12?h+=12:k[4].toLowerCase()=="am"&&h>=12&&(h-=12)));var l=function(){function k(a){d.push(a)}function j(){var a="";while(g()&&/[0-9]/.test(g()))a+=f();if(h(g()))return i(a);return parseInt(a,10)}function i(a){while(g()&&h(g()))a+=f();return a}function g(){return b.charAt(c)}function f(){return b.charAt(c++)}var c=0,d=[],e,h=a.isUnicodeLetter;while(c<b.length)e=g(),h(e)?k(i("")):/[0-9]/.test(e)?k(j()):f();return d}(),m=[];for(var n=0;n<l.length;++n){var o=l[n];/^[0-9]{4}$/.test(o)?(e=parseInt(o,10),f==null&&g==null&&c==null&&(c=!0)):/^[0-9]{1,2}$/.test(o)?(o=parseInt(o,10),o<60?o<0||o>12?o>=1&&o<=31&&(g=o):m.push(o):e=o):f==null&&(f=T(o))}m.length<2?m.length==1&&(g==null?g=m.shift():f==null&&(f=m.shift())):c?(f==null&&(f=m.shift()),g==null&&(g=m.shift())):(g==null&&(g=m.shift()),f==null&&(f=m.shift())),e==null&&(e=m.length>0?m.shift():d.getFullYear()),e<30?e+=2e3:e<99&&(e+=1900),f==null&&(f=d.getMonth()+1);return e!=null&&f!=null&&g!=null?new Date(e,f-1,g,h,i,j):null};var be={elastic_b:function(a){return 1-Math.cos(-a*5.5*Math.PI)/Math.pow(2,7*a)},magnetic:function(a){return 1-Math.cos(a*a*a*10.5*Math.PI)/Math.exp(4*a)},accel_b:function(a){a=1-a;return 1-a*a*a*a},accel_a:function(a){return a*a*a},accel_ab:function(a){a=1-a;return 1-Math.sin(a*a*Math.PI/2)},accel_ab2:function(a){return(a/=.5)<1?.5*a*a:-0.5*(--a*(a-2)-1)},brakes:function(a){a=1-a;return 1-Math.sin(a*a*Math.PI)},shake:function(a){return a<.5?-Math.cos(a*11*Math.PI)*a*a:(a=1-a,Math.cos(a*11*Math.PI)*a*a)}},bl=new Function;return a}()

Calendar.LANG("en", "English", {
        fdow: 1,                // first day of week for this locale; 0 = Sunday, 1 = Monday, etc.
        goToday: "Go Today",
        today: "Today",         // appears in bottom bar
        wk: "wk",
        weekend: "0,6",         // 0 = Sunday, 1 = Monday, etc.
        AM: "am",
        PM: "pm",
        mn : [ "January",
               "February",
               "March",
               "April",
               "May",
               "June",
               "July",
               "August",
               "September",
               "October",
               "November",
               "December" ],

        smn : [ "Jan",
                "Feb",
                "Mar",
                "Apr",
                "May",
                "Jun",
                "Jul",
                "Aug",
                "Sep",
                "Oct",
                "Nov",
                "Dec" ],

        dn : [ "Sunday",
               "Monday",
               "Tuesday",
               "Wednesday",
               "Thursday",
               "Friday",
               "Saturday",
               "Sunday" ],

        sdn : [ "Su",
                "Mo",
                "Tu",
                "We",
                "Th",
                "Fr",
                "Sa",
                "Su" ]
});
//\/////
//\  overLIB 4.21 - You may not remove or change this notice.
//\  Copyright Erik Bosrup 1998-2004. All rights reserved.
//\
//\  Contributors are listed on the homepage.
//\  This file might be old, always check for the latest version at:
//\  http://www.bosrup.com/web/overlib/
//\
//\  Please read the license agreement (available through the link above)
//\  before using overLIB. Direct any licensing questions to erik@bosrup.com.
//\
//\  Do not sell this as your own work or remove this copyright notice.
//\  For full details on copying or changing this script please read the
//\  license agreement at the link above. Please give credit on sites that
//\  use overLIB and submit changes of the script so other people can use
//\  them as well.
//   $Revision: 1.119 $                $Date: 2005/07/02 23:41:44 $
//\/////
//\mini

////////
// PRE-INIT
// Ignore these lines, configuration is below.
////////
var olLoaded = 0;var pmStart = 10000000; var pmUpper = 10001000; var pmCount = pmStart+1; var pmt=''; var pms = new Array(); var olInfo = new Info('4.21', 1);
var FREPLACE = 0; var FBEFORE = 1; var FAFTER = 2; var FALTERNATE = 3; var FCHAIN=4;
var olHideForm=0;  // parameter for hiding SELECT and ActiveX elements in IE5.5+
var olHautoFlag = 0;  // flags for over-riding VAUTO and HAUTO if corresponding
var olVautoFlag = 0;  // positioning commands are used on the command line
var hookPts = new Array(), postParse = new Array(), cmdLine = new Array(), runTime = new Array();
// for plugins
registerCommands('donothing,inarray,caparray,sticky,background,noclose,caption,left,right,center,offsetx,offsety,fgcolor,bgcolor,textcolor,capcolor,closecolor,width,border,cellpad,status,autostatus,autostatuscap,height,closetext,snapx,snapy,fixx,fixy,relx,rely,fgbackground,bgbackground,padx,pady,fullhtml,above,below,capicon,textfont,captionfont,closefont,textsize,captionsize,closesize,timeout,function,delay,hauto,vauto,closeclick,wrap,followmouse,mouseoff,closetitle,cssoff,compatmode,cssclass,fgclass,bgclass,textfontclass,captionfontclass,closefontclass');

////////
// DEFAULT CONFIGURATION
// Settings you want everywhere are set here. All of this can also be
// changed on your html page or through an overLIB call.
////////
if (typeof ol_fgcolor=='undefined') var ol_fgcolor="#CCCCFF";
if (typeof ol_bgcolor=='undefined') var ol_bgcolor="#333399";
if (typeof ol_textcolor=='undefined') var ol_textcolor="#000000";
if (typeof ol_capcolor=='undefined') var ol_capcolor="#FFFFFF";
if (typeof ol_closecolor=='undefined') var ol_closecolor="#9999FF";
if (typeof ol_textfont=='undefined') var ol_textfont="Verdana,Arial,Helvetica";
if (typeof ol_captionfont=='undefined') var ol_captionfont="Verdana,Arial,Helvetica";
if (typeof ol_closefont=='undefined') var ol_closefont="Verdana,Arial,Helvetica";
if (typeof ol_textsize=='undefined') var ol_textsize="1";
if (typeof ol_captionsize=='undefined') var ol_captionsize="1";
if (typeof ol_closesize=='undefined') var ol_closesize="1";
if (typeof ol_width=='undefined') var ol_width="200";
if (typeof ol_border=='undefined') var ol_border="1";
if (typeof ol_cellpad=='undefined') var ol_cellpad=2;
if (typeof ol_offsetx=='undefined') var ol_offsetx=10;
if (typeof ol_offsety=='undefined') var ol_offsety=10;
if (typeof ol_text=='undefined') var ol_text="Default Text";
if (typeof ol_cap=='undefined') var ol_cap="";
if (typeof ol_sticky=='undefined') var ol_sticky=0;
if (typeof ol_background=='undefined') var ol_background="";
if (typeof ol_close=='undefined') var ol_close="Close";
if (typeof ol_hpos=='undefined') var ol_hpos=RIGHT;
if (typeof ol_status=='undefined') var ol_status="";
if (typeof ol_autostatus=='undefined') var ol_autostatus=0;
if (typeof ol_height=='undefined') var ol_height=-1;
if (typeof ol_snapx=='undefined') var ol_snapx=0;
if (typeof ol_snapy=='undefined') var ol_snapy=0;
if (typeof ol_fixx=='undefined') var ol_fixx=-1;
if (typeof ol_fixy=='undefined') var ol_fixy=-1;
if (typeof ol_relx=='undefined') var ol_relx=null;
if (typeof ol_rely=='undefined') var ol_rely=null;
if (typeof ol_fgbackground=='undefined') var ol_fgbackground="";
if (typeof ol_bgbackground=='undefined') var ol_bgbackground="";
if (typeof ol_padxl=='undefined') var ol_padxl=1;
if (typeof ol_padxr=='undefined') var ol_padxr=1;
if (typeof ol_padyt=='undefined') var ol_padyt=1;
if (typeof ol_padyb=='undefined') var ol_padyb=1;
if (typeof ol_fullhtml=='undefined') var ol_fullhtml=0;
if (typeof ol_vpos=='undefined') var ol_vpos=BELOW;
if (typeof ol_aboveheight=='undefined') var ol_aboveheight=0;
if (typeof ol_capicon=='undefined') var ol_capicon="";
if (typeof ol_frame=='undefined') var ol_frame=self;
if (typeof ol_timeout=='undefined') var ol_timeout=0;
if (typeof ol_function=='undefined') var ol_function=null;
if (typeof ol_delay=='undefined') var ol_delay=0;
if (typeof ol_hauto=='undefined') var ol_hauto=0;
if (typeof ol_vauto=='undefined') var ol_vauto=0;
if (typeof ol_closeclick=='undefined') var ol_closeclick=0;
if (typeof ol_wrap=='undefined') var ol_wrap=0;
if (typeof ol_followmouse=='undefined') var ol_followmouse=1;
if (typeof ol_mouseoff=='undefined') var ol_mouseoff=0;
if (typeof ol_closetitle=='undefined') var ol_closetitle='Close';
if (typeof ol_compatmode=='undefined') var ol_compatmode=0;
if (typeof ol_css=='undefined') var ol_css=CSSOFF;
if (typeof ol_fgclass=='undefined') var ol_fgclass="";
if (typeof ol_bgclass=='undefined') var ol_bgclass="";
if (typeof ol_textfontclass=='undefined') var ol_textfontclass="";
if (typeof ol_captionfontclass=='undefined') var ol_captionfontclass="";
if (typeof ol_closefontclass=='undefined') var ol_closefontclass="";

////////
// ARRAY CONFIGURATION
////////

// You can use these arrays to store popup text here instead of in the html.
if (typeof ol_texts=='undefined') var ol_texts = new Array("Text 0", "Text 1");
if (typeof ol_caps=='undefined') var ol_caps = new Array("Caption 0", "Caption 1");

////////
// END OF CONFIGURATION
// Don't change anything below this line, all configuration is above.
////////





////////
// INIT
////////
// Runtime variables init. Don't change for config!
var o3_text="";
var o3_cap="";
var o3_sticky=0;
var o3_background="";
var o3_close="Close";
var o3_hpos=RIGHT;
var o3_offsetx=2;
var o3_offsety=2;
var o3_fgcolor="";
var o3_bgcolor="";
var o3_textcolor="";
var o3_capcolor="";
var o3_closecolor="";
var o3_width=100;
var o3_border=1;
var o3_cellpad=2;
var o3_status="";
var o3_autostatus=0;
var o3_height=-1;
var o3_snapx=0;
var o3_snapy=0;
var o3_fixx=-1;
var o3_fixy=-1;
var o3_relx=null;
var o3_rely=null;
var o3_fgbackground="";
var o3_bgbackground="";
var o3_padxl=0;
var o3_padxr=0;
var o3_padyt=0;
var o3_padyb=0;
var o3_fullhtml=0;
var o3_vpos=BELOW;
var o3_aboveheight=0;
var o3_capicon="";
var o3_textfont="Verdana,Arial,Helvetica";
var o3_captionfont="Verdana,Arial,Helvetica";
var o3_closefont="Verdana,Arial,Helvetica";
var o3_textsize="1";
var o3_captionsize="1";
var o3_closesize="1";
var o3_frame=self;
var o3_timeout=0;
var o3_timerid=0;
var o3_allowmove=0;
var o3_function=null;
var o3_delay=0;
var o3_delayid=0;
var o3_hauto=0;
var o3_vauto=0;
var o3_closeclick=0;
var o3_wrap=0;
var o3_followmouse=1;
var o3_mouseoff=0;
var o3_closetitle='';
var o3_compatmode=0;
var o3_css=CSSOFF;
var o3_fgclass="";
var o3_bgclass="";
var o3_textfontclass="";
var o3_captionfontclass="";
var o3_closefontclass="";

// Display state variables
var o3_x = 0;
var o3_y = 0;
var o3_showingsticky = 0;
var o3_removecounter = 0;

// Our layer
var over = null;
var fnRef, hoveringSwitch = false;
var olHideDelay;

// Decide browser version
var isMac = (navigator.userAgent.indexOf("Mac") != -1);
var olOp = (navigator.userAgent.toLowerCase().indexOf('opera') > -1 && document.createTextNode);  // Opera 7
var olNs4 = (navigator.appName=='Netscape' && parseInt(navigator.appVersion) == 4);
var olNs6 = (document.getElementById) ? true : false;
var olKq = (olNs6 && /konqueror/i.test(navigator.userAgent));
var olIe4 = (document.all) ? true : false;
var olIe5 = false;
var olIe55 = false; // Added additional variable to identify IE5.5+
var docRoot = 'document.body';

// Resize fix for NS4.x to keep track of layer
if (olNs4) {
	var oW = window.innerWidth;
	var oH = window.innerHeight;
	window.onresize = function() { if (oW != window.innerWidth || oH != window.innerHeight) location.reload(); }
}

// Microsoft Stupidity Check(tm).
if (olIe4) {
	var agent = navigator.userAgent;
	if (/MSIE/.test(agent)) {
		var versNum = parseFloat(agent.match(/MSIE[ ](\d\.\d+)\.*/i)[1]);
		if (versNum >= 5){
			olIe5=true;
			olIe55=(versNum>=5.5&&!olOp) ? true : false;
			if (olNs6) olNs6=false;
		}
	}
	if (olNs6) olIe4 = false;
}

// Check for compatability mode.
if (document.compatMode && document.compatMode == 'CSS1Compat') {
	docRoot= ((olIe4 && !olOp) ? 'document.documentElement' : docRoot);
}

// Add window onload handlers to indicate when all modules have been loaded
// For Netscape 6+ and Mozilla, uses addEventListener method on the window object
// For IE it uses the attachEvent method of the window object and for Netscape 4.x
// it sets the window.onload handler to the OLonload_handler function for Bubbling
if(window.addEventListener) window.addEventListener("load",OLonLoad_handler,false);
else if (window.attachEvent) window.attachEvent("onload",OLonLoad_handler);

var capExtent;

////////
// PUBLIC FUNCTIONS
////////

// overlib(arg0,...,argN)
// Loads parameters into global runtime variables.
function overlib() {
	if (!olLoaded || isExclusive(overlib.arguments)) return true;
	if (olCheckMouseCapture) olMouseCapture();
	if (over) {
		over = (typeof over.id != 'string') ? o3_frame.document.all['overDiv'] : over;
		cClick();
	}

	// Load defaults to runtime.
  olHideDelay=0;
	o3_text=ol_text;
	o3_cap=ol_cap;
	o3_sticky=ol_sticky;
	o3_background=ol_background;
	o3_close=ol_close;
	o3_hpos=ol_hpos;
	o3_offsetx=ol_offsetx;
	o3_offsety=ol_offsety;
	o3_fgcolor=ol_fgcolor;
	o3_bgcolor=ol_bgcolor;
	o3_textcolor=ol_textcolor;
	o3_capcolor=ol_capcolor;
	o3_closecolor=ol_closecolor;
	o3_width=ol_width;
	o3_border=ol_border;
	o3_cellpad=ol_cellpad;
	o3_status=ol_status;
	o3_autostatus=ol_autostatus;
	o3_height=ol_height;
	o3_snapx=ol_snapx;
	o3_snapy=ol_snapy;
	o3_fixx=ol_fixx;
	o3_fixy=ol_fixy;
	o3_relx=ol_relx;
	o3_rely=ol_rely;
	o3_fgbackground=ol_fgbackground;
	o3_bgbackground=ol_bgbackground;
	o3_padxl=ol_padxl;
	o3_padxr=ol_padxr;
	o3_padyt=ol_padyt;
	o3_padyb=ol_padyb;
	o3_fullhtml=ol_fullhtml;
	o3_vpos=ol_vpos;
	o3_aboveheight=ol_aboveheight;
	o3_capicon=ol_capicon;
	o3_textfont=ol_textfont;
	o3_captionfont=ol_captionfont;
	o3_closefont=ol_closefont;
	o3_textsize=ol_textsize;
	o3_captionsize=ol_captionsize;
	o3_closesize=ol_closesize;
	o3_timeout=ol_timeout;
	o3_function=ol_function;
	o3_delay=ol_delay;
	o3_hauto=ol_hauto;
	o3_vauto=ol_vauto;
	o3_closeclick=ol_closeclick;
	o3_wrap=ol_wrap;
	o3_followmouse=ol_followmouse;
	o3_mouseoff=ol_mouseoff;
	o3_closetitle=ol_closetitle;
	o3_css=ol_css;
	o3_compatmode=ol_compatmode;
	o3_fgclass=ol_fgclass;
	o3_bgclass=ol_bgclass;
	o3_textfontclass=ol_textfontclass;
	o3_captionfontclass=ol_captionfontclass;
	o3_closefontclass=ol_closefontclass;

	setRunTimeVariables();

	fnRef = '';

	// Special for frame support, over must be reset...
	o3_frame = ol_frame;

	if(!(over=createDivContainer())) return false;

	parseTokens('o3_', overlib.arguments);
	if (!postParseChecks()) return false;

	if (o3_delay == 0) {
		return runHook("olMain", FREPLACE);
 	} else {
		o3_delayid = setTimeout("runHook('olMain', FREPLACE)", o3_delay);
		return false;
	}
}

// Clears popups if appropriate
function nd(time) {
	if (olLoaded && !isExclusive()) {
		hideDelay(time);  // delay popup close if time specified

		if (o3_removecounter >= 1) { o3_showingsticky = 0 };

		if (o3_showingsticky == 0) {
			o3_allowmove = 0;
			if (over != null && o3_timerid == 0) runHook("hideObject", FREPLACE, over);
		} else {
			o3_removecounter++;
		}
	}

	return true;
}

// The Close onMouseOver function for stickies
function cClick() {
	if (olLoaded) {
		runHook("hideObject", FREPLACE, over);
		o3_showingsticky = 0;
	}
	return false;
}

// Method for setting page specific defaults.
function overlib_pagedefaults() {
	parseTokens('ol_', overlib_pagedefaults.arguments);
}


////////
// OVERLIB MAIN FUNCTION
////////

// This function decides what it is we want to display and how we want it done.
function olMain() {
	var layerhtml, styleType;
 	runHook("olMain", FBEFORE);

	if (o3_background!="" || o3_fullhtml) {
		// Use background instead of box.
		layerhtml = runHook('ol_content_background', FALTERNATE, o3_css, o3_text, o3_background, o3_fullhtml);
	} else {
		// They want a popup box.
		styleType = (pms[o3_css-1-pmStart] == "cssoff" || pms[o3_css-1-pmStart] == "cssclass");

		// Prepare popup background
		if (o3_fgbackground != "") o3_fgbackground = "background=\""+o3_fgbackground+"\"";
		if (o3_bgbackground != "") o3_bgbackground = (styleType ? "background=\""+o3_bgbackground+"\"" : o3_bgbackground);

		// Prepare popup colors
		if (o3_fgcolor != "") o3_fgcolor = (styleType ? "bgcolor=\""+o3_fgcolor+"\"" : o3_fgcolor);
		if (o3_bgcolor != "") o3_bgcolor = (styleType ? "bgcolor=\""+o3_bgcolor+"\"" : o3_bgcolor);

		// Prepare popup height
		if (o3_height > 0) o3_height = (styleType ? "height=\""+o3_height+"\"" : o3_height);
		else o3_height = "";

		// Decide which kinda box.
		if (o3_cap=="") {
			// Plain
			layerhtml = runHook('ol_content_simple', FALTERNATE, o3_css, o3_text);
		} else {
			// With caption
			if (o3_sticky) {
				// Show close text
				layerhtml = runHook('ol_content_caption', FALTERNATE, o3_css, o3_text, o3_cap, o3_close);
			} else {
				// No close text
				layerhtml = runHook('ol_content_caption', FALTERNATE, o3_css, o3_text, o3_cap, "");
			}
		}
	}

	// We want it to stick!
	if (o3_sticky) {
		if (o3_timerid > 0) {
			clearTimeout(o3_timerid);
			o3_timerid = 0;
		}
		o3_showingsticky = 1;
		o3_removecounter = 0;
	}

	// Created a separate routine to generate the popup to make it easier
	// to implement a plugin capability
	if (!runHook("createPopup", FREPLACE, layerhtml)) return false;

	// Prepare status bar
	if (o3_autostatus > 0) {
		o3_status = o3_text;
		if (o3_autostatus > 1) o3_status = o3_cap;
	}

	// When placing the layer the first time, even stickies may be moved.
	o3_allowmove = 0;

	// Initiate a timer for timeout
	if (o3_timeout > 0) {
		if (o3_timerid > 0) clearTimeout(o3_timerid);
		o3_timerid = setTimeout("cClick()", o3_timeout);
	}

	// Show layer
	runHook("disp", FREPLACE, o3_status);
	runHook("olMain", FAFTER);

	return (olOp && event && event.type == 'mouseover' && !o3_status) ? '' : (o3_status != '');
}

////////
// LAYER GENERATION FUNCTIONS
////////
// These functions just handle popup content with tags that should adhere to the W3C standards specification.

// Makes simple table without caption
function ol_content_simple(text) {
	var cpIsMultiple = /,/.test(o3_cellpad);
	var txt = '<table class="overDivHead" width="'+o3_width+ '" border="0" cellpadding="'+o3_border+'" cellspacing="0" '+(o3_bgclass ? 'class="'+o3_bgclass+'"' : o3_bgcolor+' '+o3_height)+'><tr><td><table class="overDivContent" width="100%" border="0" '+((olNs4||!cpIsMultiple) ? 'cellpadding="'+o3_cellpad+'" ' : '')+'cellspacing="0" '+(o3_fgclass ? 'class="'+o3_fgclass+'"' : o3_fgcolor+' '+o3_fgbackground+' '+o3_height)+'><tr><td valign="TOP"'+(o3_textfontclass ? ' class="'+o3_textfontclass+'">' : ((!olNs4&&cpIsMultiple) ? ' style="'+setCellPadStr(o3_cellpad)+'">' : '>'))+(o3_textfontclass ? '' : wrapStr(0,o3_textsize,'text'))+text+(o3_textfontclass ? '' : wrapStr(1,o3_textsize))+'</td></tr></table></td></tr></table>';

	set_background("");
	return txt;
}

// Makes table with caption and optional close link
function ol_content_caption(text,title,close) {
	var nameId, txt, cpIsMultiple = /,/.test(o3_cellpad);
	var closing, closeevent;

	closing = "";
	closeevent = "onmouseover";
	if (o3_closeclick == 1) closeevent = (o3_closetitle ? "title='" + o3_closetitle +"'" : "") + " onclick";
	if (o3_capicon != "") {
	  nameId = ' hspace = \"5\"'+' align = \"middle\" alt = \"\"';
	  if (typeof o3_dragimg != 'undefined' && o3_dragimg) nameId =' hspace=\"5\"'+' name=\"'+o3_dragimg+'\" id=\"'+o3_dragimg+'\" align=\"middle\" alt=\"Drag Enabled\" title=\"Drag Enabled\"';
	  o3_capicon = '<img src=\"'+o3_capicon+'\"'+nameId+' />';
	}

	if (close != "")
		closing = '<td '+(!o3_compatmode && o3_closefontclass ? 'class="'+o3_closefontclass : 'align="RIGHT')+'"><a href="javascript:return '+fnRef+'cClick();"'+((o3_compatmode && o3_closefontclass) ? ' class="' + o3_closefontclass + '" ' : ' ')+closeevent+'="return '+fnRef+'cClick();">'+(o3_closefontclass ? '' : wrapStr(0,o3_closesize,'close'))+close+(o3_closefontclass ? '' : wrapStr(1,o3_closesize,'close'))+'</a></td>';
	txt = '<table class="overDivTable" width="'+o3_width+ '" border="0" cellpadding="'+o3_border+'" cellspacing="0" '+(o3_bgclass ? 'class="'+o3_bgclass+'"' : o3_bgcolor+' '+o3_bgbackground+' '+o3_height)+'><tr><td><table class="overDivHead" width="100%" border="0" cellpadding="2" cellspacing="0"><tr><td'+(o3_captionfontclass ? ' class="'+o3_captionfontclass+'">' : '>')+(o3_captionfontclass ? '' : '<b>'+wrapStr(0,o3_captionsize,'caption'))+o3_capicon+title+(o3_captionfontclass ? '' : wrapStr(1,o3_captionsize)+'</b>')+'</td>'+closing+'</tr></table><table class="overDivContent" width="100%" border="0" '+((olNs4||!cpIsMultiple) ? 'cellpadding="'+o3_cellpad+'" ' : '')+'cellspacing="0" '+(o3_fgclass ? 'class="'+o3_fgclass+'"' : o3_fgcolor+' '+o3_fgbackground+' '+o3_height)+'><tr><td valign="TOP"'+(o3_textfontclass ? ' class="'+o3_textfontclass+'">' :((!olNs4&&cpIsMultiple) ? ' style="'+setCellPadStr(o3_cellpad)+'">' : '>'))+(o3_textfontclass ? '' : wrapStr(0,o3_textsize,'text'))+text+(o3_textfontclass ? '' : wrapStr(1,o3_textsize)) + '</td></tr></table></td></tr></table>';

	set_background("");
	return txt;
}

// Sets the background picture,padding and lots more. :)
function ol_content_background(text,picture,hasfullhtml) {
	if (hasfullhtml) {
		txt=text;
	} else {
		txt='<table width="'+o3_width+'" border="0" cellpadding="0" cellspacing="0" height="'+o3_height+'"><tr><td colspan="3" height="'+o3_padyt+'"></td></tr><tr><td width="'+o3_padxl+'"></td><td valign="TOP" width="'+(o3_width-o3_padxl-o3_padxr)+(o3_textfontclass ? '" class="'+o3_textfontclass : '')+'">'+(o3_textfontclass ? '' : wrapStr(0,o3_textsize,'text'))+text+(o3_textfontclass ? '' : wrapStr(1,o3_textsize))+'</td><td width="'+o3_padxr+'"></td></tr><tr><td colspan="3" height="'+o3_padyb+'"></td></tr></table>';
	}

	set_background(picture);
	return txt;
}

// Loads a picture into the div.
function set_background(pic) {
	if (pic == "") {
		if (olNs4) {
			over.background.src = null;
		} else if (over.style) {
			over.style.backgroundImage = "none";
		}
	} else {
		if (olNs4) {
			over.background.src = pic;
		} else if (over.style) {
			over.style.width=o3_width + 'px';
			over.style.backgroundImage = "url("+pic+")";
		}
	}
}

////////
// HANDLING FUNCTIONS
////////
var olShowId=-1;

// Displays the popup
function disp(statustext) {
	runHook("disp", FBEFORE);

	if (o3_allowmove == 0) {
		runHook("placeLayer", FREPLACE);
		(olNs6&&olShowId<0) ? olShowId=setTimeout("runHook('showObject', FREPLACE, over)", 1) : runHook("showObject", FREPLACE, over);
		o3_allowmove = (o3_sticky || o3_followmouse==0) ? 0 : 1;
	}

	runHook("disp", FAFTER);

	if (statustext != "") self.status = statustext;
}

// Creates the actual popup structure
function createPopup(lyrContent){
	runHook("createPopup", FBEFORE);

	if (o3_wrap) {
		var wd,ww,theObj = (olNs4 ? over : over.style);
		theObj.top = theObj.left = ((olIe4&&!olOp) ? 0 : -10000) + (!olNs4 ? 'px' : 0);
		layerWrite(lyrContent);
		wd = (olNs4 ? over.clip.width : over.offsetWidth);
		if (wd > (ww=windowWidth())) {
			lyrContent=lyrContent.replace(/\&nbsp;/g, ' ');
			o3_width=ww;
			o3_wrap=0;
		}
	}

	layerWrite(lyrContent);

	// Have to set o3_width for placeLayer() routine if o3_wrap is turned on
	if (o3_wrap) o3_width=(olNs4 ? over.clip.width : over.offsetWidth);

	runHook("createPopup", FAFTER, lyrContent);

	return true;
}

// Decides where we want the popup.
function placeLayer() {
	var placeX, placeY, widthFix = 0;

	// HORIZONTAL PLACEMENT, re-arranged to work in Safari
	if (o3_frame.innerWidth) widthFix=18;
	iwidth = windowWidth();

	// Horizontal scroll offset
	winoffset=(olIe4) ? eval('o3_frame.'+docRoot+'.scrollLeft') : o3_frame.pageXOffset;

	placeX = runHook('horizontalPlacement',FCHAIN,iwidth,winoffset,widthFix);

	// VERTICAL PLACEMENT, re-arranged to work in Safari
	if (o3_frame.innerHeight) {
		iheight=o3_frame.innerHeight;
	} else if (eval('o3_frame.'+docRoot)&&eval("typeof o3_frame."+docRoot+".clientHeight=='number'")&&eval('o3_frame.'+docRoot+'.clientHeight')) {
		iheight=eval('o3_frame.'+docRoot+'.clientHeight');
	}

	// Vertical scroll offset
	scrolloffset=(olIe4) ? eval('o3_frame.'+docRoot+'.scrollTop') : o3_frame.pageYOffset;
	placeY = runHook('verticalPlacement',FCHAIN,iheight,scrolloffset);

	// Actually move the object.
	repositionTo(over, placeX, placeY);
}

// Moves the layer
function olMouseMove(e) {
	var e = (e) ? e : event;

	if (e.pageX) {
		o3_x = e.pageX;
		o3_y = e.pageY;
	} else if (e.clientX) {
		o3_x = eval('e.clientX+o3_frame.'+docRoot+'.scrollLeft');
		o3_y = eval('e.clientY+o3_frame.'+docRoot+'.scrollTop');
	}

	if (o3_allowmove == 1) runHook("placeLayer", FREPLACE);

	// MouseOut handler
	if (hoveringSwitch && !olNs4 && runHook("cursorOff", FREPLACE)) {
		(olHideDelay ? hideDelay(olHideDelay) : cClick());
		hoveringSwitch = !hoveringSwitch;
	}
}

// Fake function for 3.0 users.
function no_overlib() { return ver3fix; }

// Capture the mouse and chain other scripts.
function olMouseCapture() {
	capExtent = document;
	var fN, str = '', l, k, f, wMv, sS, mseHandler = olMouseMove;
	var re = /function[ ]*(\w*)\(/;

	wMv = (!olIe4 && window.onmousemove);
	if (document.onmousemove || wMv) {
		if (wMv) capExtent = window;
		f = capExtent.onmousemove.toString();
		fN = f.match(re);
		if (fN == null) {
			str = f+'(e); ';
		} else if (fN[1] == 'anonymous' || fN[1] == 'olMouseMove' || (wMv && fN[1] == 'onmousemove')) {
			if (!olOp && wMv) {
				l = f.indexOf('{')+1;
				k = f.lastIndexOf('}');
				sS = f.substring(l,k);
				if ((l = sS.indexOf('(')) != -1) {
					sS = sS.substring(0,l).replace(/^\s+/,'').replace(/\s+$/,'');
					if (eval("typeof " + sS + " == 'undefined'")) window.onmousemove = null;
					else str = sS + '(e);';
				}
			}
			if (!str) {
				olCheckMouseCapture = false;
				return;
			}
		} else {
			if (fN[1]) str = fN[1]+'(e); ';
			else {
				l = f.indexOf('{')+1;
				k = f.lastIndexOf('}');
				str = f.substring(l,k) + '\n';
			}
		}
		str += 'olMouseMove(e); ';
		mseHandler = new Function('e', str);
	}

	capExtent.onmousemove = mseHandler;
	if (olNs4) capExtent.captureEvents(Event.MOUSEMOVE);
}

////////
// PARSING FUNCTIONS
////////

// Does the actual command parsing.
function parseTokens(pf, ar) {
	// What the next argument is expected to be.
	var v, i, mode=-1, par = (pf != 'ol_');
	var fnMark = (par && !ar.length ? 1 : 0);

	for (i = 0; i < ar.length; i++) {
		if (mode < 0) {
			// Arg is maintext,unless its a number between pmStart and pmUpper
			// then its a command.
			if (typeof ar[i] == 'number' && ar[i] > pmStart && ar[i] < pmUpper) {
				fnMark = (par ? 1 : 0);
				i--;   // backup one so that the next block can parse it
			} else {
				switch(pf) {
					case 'ol_':
						ol_text = ar[i].toString();
						break;
					default:
						o3_text=ar[i].toString();
				}
			}
			mode = 0;
		} else {
			// Note: NS4 doesn't like switch cases with vars.
			if (ar[i] >= pmCount || ar[i]==DONOTHING) { continue; }
			if (ar[i]==INARRAY) { fnMark = 0; eval(pf+'text=ol_texts['+ar[++i]+'].toString()'); continue; }
			if (ar[i]==CAPARRAY) { eval(pf+'cap=ol_caps['+ar[++i]+'].toString()'); continue; }
			if (ar[i]==STICKY) { if (pf!='ol_') eval(pf+'sticky=1'); continue; }
			if (ar[i]==BACKGROUND) { eval(pf+'background="'+ar[++i]+'"'); continue; }
			if (ar[i]==NOCLOSE) { if (pf!='ol_') opt_NOCLOSE(); continue; }
			if (ar[i]==CAPTION) { eval(pf+"cap='"+escSglQuote(ar[++i])+"'"); continue; }
			if (ar[i]==CENTER || ar[i]==LEFT || ar[i]==RIGHT) { eval(pf+'hpos='+ar[i]); if(pf!='ol_') olHautoFlag=1; continue; }
			if (ar[i]==OFFSETX) { eval(pf+'offsetx='+ar[++i]); continue; }
			if (ar[i]==OFFSETY) { eval(pf+'offsety='+ar[++i]); continue; }
			if (ar[i]==FGCOLOR) { eval(pf+'fgcolor="'+ar[++i]+'"'); continue; }
			if (ar[i]==BGCOLOR) { eval(pf+'bgcolor="'+ar[++i]+'"'); continue; }
			if (ar[i]==TEXTCOLOR) { eval(pf+'textcolor="'+ar[++i]+'"'); continue; }
			if (ar[i]==CAPCOLOR) { eval(pf+'capcolor="'+ar[++i]+'"'); continue; }
			if (ar[i]==CLOSECOLOR) { eval(pf+'closecolor="'+ar[++i]+'"'); continue; }
			if (ar[i]==WIDTH) { eval(pf+'width='+ar[++i]); continue; }
			if (ar[i]==BORDER) { eval(pf+'border='+ar[++i]); continue; }
			if (ar[i]==CELLPAD) { i=opt_MULTIPLEARGS(++i,ar,(pf+'cellpad')); continue; }
			if (ar[i]==STATUS) { eval(pf+"status='"+escSglQuote(ar[++i])+"'"); continue; }
			if (ar[i]==AUTOSTATUS) { eval(pf +'autostatus=('+pf+'autostatus == 1) ? 0 : 1'); continue; }
			if (ar[i]==AUTOSTATUSCAP) { eval(pf +'autostatus=('+pf+'autostatus == 2) ? 0 : 2'); continue; }
			if (ar[i]==HEIGHT) { eval(pf+'height='+pf+'aboveheight='+ar[++i]); continue; } // Same param again.
			if (ar[i]==CLOSETEXT) { eval(pf+"close='"+escSglQuote(ar[++i])+"'"); continue; }
			if (ar[i]==SNAPX) { eval(pf+'snapx='+ar[++i]); continue; }
			if (ar[i]==SNAPY) { eval(pf+'snapy='+ar[++i]); continue; }
			if (ar[i]==FIXX) { eval(pf+'fixx='+ar[++i]); continue; }
			if (ar[i]==FIXY) { eval(pf+'fixy='+ar[++i]); continue; }
			if (ar[i]==RELX) { eval(pf+'relx='+ar[++i]); continue; }
			if (ar[i]==RELY) { eval(pf+'rely='+ar[++i]); continue; }
			if (ar[i]==FGBACKGROUND) { eval(pf+'fgbackground="'+ar[++i]+'"'); continue; }
			if (ar[i]==BGBACKGROUND) { eval(pf+'bgbackground="'+ar[++i]+'"'); continue; }
			if (ar[i]==PADX) { eval(pf+'padxl='+ar[++i]); eval(pf+'padxr='+ar[++i]); continue; }
			if (ar[i]==PADY) { eval(pf+'padyt='+ar[++i]); eval(pf+'padyb='+ar[++i]); continue; }
			if (ar[i]==FULLHTML) { if (pf!='ol_') eval(pf+'fullhtml=1'); continue; }
			if (ar[i]==BELOW || ar[i]==ABOVE) { eval(pf+'vpos='+ar[i]); if (pf!='ol_') olVautoFlag=1; continue; }
			if (ar[i]==CAPICON) { eval(pf+'capicon="'+ar[++i]+'"'); continue; }
			if (ar[i]==TEXTFONT) { eval(pf+"textfont='"+escSglQuote(ar[++i])+"'"); continue; }
			if (ar[i]==CAPTIONFONT) { eval(pf+"captionfont='"+escSglQuote(ar[++i])+"'"); continue; }
			if (ar[i]==CLOSEFONT) { eval(pf+"closefont='"+escSglQuote(ar[++i])+"'"); continue; }
			if (ar[i]==TEXTSIZE) { eval(pf+'textsize="'+ar[++i]+'"'); continue; }
			if (ar[i]==CAPTIONSIZE) { eval(pf+'captionsize="'+ar[++i]+'"'); continue; }
			if (ar[i]==CLOSESIZE) { eval(pf+'closesize="'+ar[++i]+'"'); continue; }
			if (ar[i]==TIMEOUT) { eval(pf+'timeout='+ar[++i]); continue; }
			if (ar[i]==FUNCTION) { if (pf=='ol_') { if (typeof ar[i+1]!='number') { v=ar[++i]; ol_function=(typeof v=='function' ? v : null); }} else {fnMark = 0; v = null; if (typeof ar[i+1]!='number') v = ar[++i];  opt_FUNCTION(v); } continue; }
			if (ar[i]==DELAY) { eval(pf+'delay='+ar[++i]); continue; }
			if (ar[i]==HAUTO) { eval(pf+'hauto=('+pf+'hauto == 0) ? 1 : 0'); continue; }
			if (ar[i]==VAUTO) { eval(pf+'vauto=('+pf+'vauto == 0) ? 1 : 0'); continue; }
			if (ar[i]==CLOSECLICK) { eval(pf +'closeclick=('+pf+'closeclick == 0) ? 1 : 0'); continue; }
			if (ar[i]==WRAP) { eval(pf +'wrap=('+pf+'wrap == 0) ? 1 : 0'); continue; }
			if (ar[i]==FOLLOWMOUSE) { eval(pf +'followmouse=('+pf+'followmouse == 1) ? 0 : 1'); continue; }
			if (ar[i]==MOUSEOFF) { eval(pf +'mouseoff=('+pf+'mouseoff==0) ? 1 : 0'); v=ar[i+1]; if (pf != 'ol_' && eval(pf+'mouseoff') && typeof v == 'number' && (v < pmStart || v > pmUpper)) olHideDelay=ar[++i]; continue; }
			if (ar[i]==CLOSETITLE) { eval(pf+"closetitle='"+escSglQuote(ar[++i])+"'"); continue; }
			if (ar[i]==CSSOFF||ar[i]==CSSCLASS) { eval(pf+'css='+ar[i]); continue; }
			if (ar[i]==COMPATMODE) { eval(pf+'compatmode=('+pf+'compatmode==0) ? 1 : 0'); continue; }
			if (ar[i]==FGCLASS) { eval(pf+'fgclass="'+ar[++i]+'"'); continue; }
			if (ar[i]==BGCLASS) { eval(pf+'bgclass="'+ar[++i]+'"'); continue; }
			if (ar[i]==TEXTFONTCLASS) { eval(pf+'textfontclass="'+ar[++i]+'"'); continue; }
			if (ar[i]==CAPTIONFONTCLASS) { eval(pf+'captionfontclass="'+ar[++i]+'"'); continue; }
			if (ar[i]==CLOSEFONTCLASS) { eval(pf+'closefontclass="'+ar[++i]+'"'); continue; }
			i = parseCmdLine(pf, i, ar);
		}
	}

	if (fnMark && o3_function) o3_text = o3_function();

	if ((pf == 'o3_') && o3_wrap) {
		o3_width = 0;

		var tReg=/<.*\n*>/ig;
		if (!tReg.test(o3_text)) o3_text = o3_text.replace(/[ ]+/g, '&nbsp;');
		if (!tReg.test(o3_cap))o3_cap = o3_cap.replace(/[ ]+/g, '&nbsp;');
	}
	if ((pf == 'o3_') && o3_sticky) {
		if (!o3_close && (o3_frame != ol_frame)) o3_close = ol_close;
		if (o3_mouseoff && (o3_frame == ol_frame)) opt_NOCLOSE(' ');
	}
}


////////
// LAYER FUNCTIONS
////////

// Writes to a layer
function layerWrite(txt) {
	txt += "\n";
	if (olNs4) {
		var lyr = o3_frame.document.layers['overDiv'].document
		lyr.write(txt)
		lyr.close()
	} else if (typeof over.innerHTML != 'undefined') {
		if (olIe5 && isMac) over.innerHTML = '';
		over.innerHTML = txt;
	} else {
		range = o3_frame.document.createRange();
		range.setStartAfter(over);
		domfrag = range.createContextualFragment(txt);

		while (over.hasChildNodes()) {
			over.removeChild(over.lastChild);
		}

		over.appendChild(domfrag);
	}
}

// Make an object visible
function showObject(obj) {
	runHook("showObject", FBEFORE);

	var theObj=(olNs4 ? obj : obj.style);
	theObj.visibility = 'visible';

	runHook("showObject", FAFTER);
}

// Hides an object
function hideObject(obj) {
	runHook("hideObject", FBEFORE);

	var theObj=(olNs4 ? obj : obj.style);
	if (olNs6 && olShowId>0) { clearTimeout(olShowId); olShowId=0; }
	theObj.visibility = 'hidden';
	theObj.top = theObj.left = ((olIe4&&!olOp) ? 0 : -10000) + (!olNs4 ? 'px' : 0);

	if (o3_timerid > 0) clearTimeout(o3_timerid);
	if (o3_delayid > 0) clearTimeout(o3_delayid);

	o3_timerid = 0;
	o3_delayid = 0;
	self.status = "";

	if (obj.onmouseout||obj.onmouseover) {
		if (olNs4) obj.releaseEvents(Event.MOUSEOUT || Event.MOUSEOVER);
		obj.onmouseout = obj.onmouseover = null;
	}

	runHook("hideObject", FAFTER);
}

// Move a layer
function repositionTo(obj, xL, yL) {
	var theObj=(olNs4 ? obj : obj.style);
	theObj.left = xL + (!olNs4 ? 'px' : 0);
	theObj.top = yL + (!olNs4 ? 'px' : 0);
}

// Check position of cursor relative to overDiv DIVision; mouseOut function
function cursorOff() {
	var left = parseInt(over.style.left);
	var top = parseInt(over.style.top);
	var right = left + (over.offsetWidth >= parseInt(o3_width) ? over.offsetWidth : parseInt(o3_width));
	var bottom = top + (over.offsetHeight >= o3_aboveheight ? over.offsetHeight : o3_aboveheight);

	if (o3_x < left || o3_x > right || o3_y < top || o3_y > bottom) return true;

	return false;
}


////////
// COMMAND FUNCTIONS
////////

// Calls callme or the default function.
function opt_FUNCTION(callme) {
	o3_text = (callme ? (typeof callme=='string' ? (/.+\(.*\)/.test(callme) ? eval(callme) : callme) : callme()) : (o3_function ? o3_function() : 'No Function'));

	return 0;
}

// Handle hovering
function opt_NOCLOSE(unused) {
	if (!unused) o3_close = "";

	if (olNs4) {
		over.captureEvents(Event.MOUSEOUT || Event.MOUSEOVER);
		over.onmouseover = function () { if (o3_timerid > 0) { clearTimeout(o3_timerid); o3_timerid = 0; } }
		over.onmouseout = function (e) { if (olHideDelay) hideDelay(olHideDelay); else cClick(e); }
	} else {
		over.onmouseover = function () {hoveringSwitch = true; if (o3_timerid > 0) { clearTimeout(o3_timerid); o3_timerid =0; } }
	}

	return 0;
}

// Function to scan command line arguments for multiples
function opt_MULTIPLEARGS(i, args, parameter) {
  var k=i, re, pV, str='';

  for(k=i; k<args.length; k++) {
		if(typeof args[k] == 'number' && args[k]>pmStart) break;
		str += args[k] + ',';
	}
	if (str) str = str.substring(0,--str.length);

	k--;  // reduce by one so the for loop this is in works correctly
	pV=(olNs4 && /cellpad/i.test(parameter)) ? str.split(',')[0] : str;
	eval(parameter + '="' + pV + '"');

	return k;
}

// Remove &nbsp; in texts when done.
function nbspCleanup() {
	if (o3_wrap) {
		o3_text = o3_text.replace(/\&nbsp;/g, ' ');
		o3_cap = o3_cap.replace(/\&nbsp;/g, ' ');
	}
}

// Escape embedded single quotes in text strings
function escSglQuote(str) {
  return str.toString().replace(/'/g,"\\'");
}

// Onload handler for window onload event
function OLonLoad_handler(e) {
	var re = /\w+\(.*\)[;\s]+/g, olre = /overlib\(|nd\(|cClick\(/, fn, l, i;

	if(!olLoaded) olLoaded=1;

  // Remove it for Gecko based browsers
	if(window.removeEventListener && e.eventPhase == 3) window.removeEventListener("load",OLonLoad_handler,false);
	else if(window.detachEvent) { // and for IE and Opera 4.x but execute calls to overlib, nd, or cClick()
		window.detachEvent("onload",OLonLoad_handler);
		var fN = document.body.getAttribute('onload');
		if (fN) {
			fN=fN.toString().match(re);
			if (fN && fN.length) {
				for (i=0; i<fN.length; i++) {
					if (/anonymous/.test(fN[i])) continue;
					while((l=fN[i].search(/\)[;\s]+/)) != -1) {
						fn=fN[i].substring(0,l+1);
						fN[i] = fN[i].substring(l+2);
						if (olre.test(fn)) eval(fn);
					}
				}
			}
		}
	}
}

// Wraps strings in Layer Generation Functions with the correct tags
//    endWrap true(if end tag) or false if start tag
//    fontSizeStr - font size string such as '1' or '10px'
//    whichString is being wrapped -- 'text', 'caption', or 'close'
function wrapStr(endWrap,fontSizeStr,whichString) {
	var fontStr, fontColor, isClose=((whichString=='close') ? 1 : 0), hasDims=/[%\-a-z]+$/.test(fontSizeStr);
	fontSizeStr = (olNs4) ? (!hasDims ? fontSizeStr : '1') : fontSizeStr;
	if (endWrap) return (hasDims&&!olNs4) ? (isClose ? '</span>' : '</div>') : '</font>';
	else {
		return (hasDims&&!olNs4) ? (isClose ? '<span>' : '<div>') : '';
	}
}

// Quotes Multi word font names; needed for CSS Standards adherence in font-family
function quoteMultiNameFonts(theFont) {
	var v, pM=theFont.split(',');
	for (var i=0; i<pM.length; i++) {
		v=pM[i];
		v=v.replace(/^\s+/,'').replace(/\s+$/,'');
		if(/\s/.test(v) && !/['"]/.test(v)) {
			v="\'"+v+"\'";
			pM[i]=v;
		}
	}
	return pM.join();
}

// dummy function which will be overridden
function isExclusive(args) {
	return false;
}

// Sets cellpadding style string value
function setCellPadStr(parameter) {
	var Str='', j=0, ary = new Array(), top, bottom, left, right;

	Str+='padding: ';
	ary=parameter.replace(/\s+/g,'').split(',');

	switch(ary.length) {
		case 2:
			top=bottom=ary[j];
			left=right=ary[++j];
			break;
		case 3:
			top=ary[j];
			left=right=ary[++j];
			bottom=ary[++j];
			break;
		case 4:
			top=ary[j];
			right=ary[++j];
			bottom=ary[++j];
			left=ary[++j];
			break;
	}

	Str+= ((ary.length==1) ? ary[0] + 'px;' : top + 'px ' + right + 'px ' + bottom + 'px ' + left + 'px;');

	return Str;
}

// function will delay close by time milliseconds
function hideDelay(time) {
	if (time&&!o3_delay) {
		if (o3_timerid > 0) clearTimeout(o3_timerid);

		o3_timerid=setTimeout("cClick()",(o3_timeout=time));
	}
}

// Was originally in the placeLayer() routine; separated out for future ease
function horizontalPlacement(browserWidth, horizontalScrollAmount, widthFix) {
	var placeX, iwidth=browserWidth, winoffset=horizontalScrollAmount;
	var parsedWidth = parseInt(o3_width);

	if (o3_fixx > -1 || o3_relx != null) {
		// Fixed position
		placeX=(o3_relx != null ? ( o3_relx < 0 ? winoffset +o3_relx+ iwidth - parsedWidth - widthFix : winoffset+o3_relx) : o3_fixx);
	} else {
		// If HAUTO, decide what to use.
		if (o3_hauto == 1) {
			if ((o3_x - winoffset) > (iwidth / 2)) {
				o3_hpos = LEFT;
			} else {
				o3_hpos = RIGHT;
			}
		}

		// From mouse
		if (o3_hpos == CENTER) { // Center
			placeX = o3_x+o3_offsetx-(parsedWidth/2);

			if (placeX < winoffset) placeX = winoffset;
		}

		if (o3_hpos == RIGHT) { // Right
			placeX = o3_x+o3_offsetx;

			if ((placeX+parsedWidth) > (winoffset+iwidth - widthFix)) {
				placeX = iwidth+winoffset - parsedWidth - widthFix;
				if (placeX < 0) placeX = 0;
			}
		}
		if (o3_hpos == LEFT) { // Left
			placeX = o3_x-o3_offsetx-parsedWidth;
			if (placeX < winoffset) placeX = winoffset;
		}

		// Snapping!
		if (o3_snapx > 1) {
			var snapping = placeX % o3_snapx;

			if (o3_hpos == LEFT) {
				placeX = placeX - (o3_snapx+snapping);
			} else {
				// CENTER and RIGHT
				placeX = placeX+(o3_snapx - snapping);
			}

			if (placeX < winoffset) placeX = winoffset;
		}
	}

	return placeX;
}

// was originally in the placeLayer() routine; separated out for future ease
function verticalPlacement(browserHeight,verticalScrollAmount) {
	var placeY, iheight=browserHeight, scrolloffset=verticalScrollAmount;
	var parsedHeight=(o3_aboveheight ? parseInt(o3_aboveheight) : (olNs4 ? over.clip.height : over.offsetHeight));

	if (o3_fixy > -1 || o3_rely != null) {
		// Fixed position
		placeY=(o3_rely != null ? (o3_rely < 0 ? scrolloffset+o3_rely+iheight - parsedHeight : scrolloffset+o3_rely) : o3_fixy);
	} else {
		// If VAUTO, decide what to use.
		if (o3_vauto == 1) {
			if ((o3_y - scrolloffset) > (iheight / 2) && o3_vpos == BELOW && (o3_y + parsedHeight + o3_offsety - (scrolloffset + iheight) > 0)) {
				o3_vpos = ABOVE;
			} else if (o3_vpos == ABOVE && (o3_y - (parsedHeight + o3_offsety) - scrolloffset < 0)) {
				o3_vpos = BELOW;
			}
		}

		// From mouse
		if (o3_vpos == ABOVE) {
			if (o3_aboveheight == 0) o3_aboveheight = parsedHeight;

			placeY = o3_y - (o3_aboveheight+o3_offsety);
			if (placeY < scrolloffset) placeY = scrolloffset;
		} else {
			// BELOW
			placeY = o3_y+o3_offsety;
		}

		// Snapping!
		if (o3_snapy > 1) {
			var snapping = placeY % o3_snapy;

			if (o3_aboveheight > 0 && o3_vpos == ABOVE) {
				placeY = placeY - (o3_snapy+snapping);
			} else {
				placeY = placeY+(o3_snapy - snapping);
			}

			if (placeY < scrolloffset) placeY = scrolloffset;
		}
	}

	return placeY;
}

// checks positioning flags
function checkPositionFlags() {
	if (olHautoFlag) olHautoFlag = o3_hauto=0;
	if (olVautoFlag) olVautoFlag = o3_vauto=0;
	return true;
}

// get Browser window width
function windowWidth() {
	var w;
	if (o3_frame.innerWidth) w=o3_frame.innerWidth;
	else if (eval('o3_frame.'+docRoot)&&eval("typeof o3_frame."+docRoot+".clientWidth=='number'")&&eval('o3_frame.'+docRoot+'.clientWidth'))
		w=eval('o3_frame.'+docRoot+'.clientWidth');
	return w;
}

// create the div container for popup content if it doesn't exist
function createDivContainer(id,frm,zValue) {
	id = (id || 'overDiv'), frm = (frm || o3_frame), zValue = (zValue || 1000);
	var objRef, divContainer = layerReference(id);

	if (divContainer == null) {
		if (olNs4) {
			divContainer = frm.document.layers[id] = new Layer(window.innerWidth, frm);
			objRef = divContainer;
		} else {
			var body = (olIe4 ? frm.document.all.tags('BODY')[0] : frm.document.getElementsByTagName("BODY")[0]);
			if (olIe4&&!document.getElementById) {
				body.insertAdjacentHTML("beforeEnd",'<div id="'+id+'"></div>');
				divContainer=layerReference(id);
			} else {
				divContainer = frm.document.createElement("DIV");
				divContainer.id = id;
				body.appendChild(divContainer);
			}
			objRef = divContainer.style;
		}

		objRef.position = 'absolute';
		objRef.visibility = 'hidden';
		objRef.zIndex = zValue;
		if (olIe4&&!olOp) objRef.left = objRef.top = '0px';
		else objRef.left = objRef.top =  -10000 + (!olNs4 ? 'px' : 0);
	}

	return divContainer;
}

// get reference to a layer with ID=id
function layerReference(id) {
	return (olNs4 ? o3_frame.document.layers[id] : (document.all ? o3_frame.document.all[id] : o3_frame.document.getElementById(id)));
}
////////
//  UTILITY FUNCTIONS
////////

// Checks if something is a function.
function isFunction(fnRef) {
	var rtn = true;

	if (typeof fnRef == 'object') {
		for (var i = 0; i < fnRef.length; i++) {
			if (typeof fnRef[i]=='function') continue;
			rtn = false;
			break;
		}
	} else if (typeof fnRef != 'function') {
		rtn = false;
	}

	return rtn;
}

// Converts an array into an argument string for use in eval.
function argToString(array, strtInd, argName) {
	var jS = strtInd, aS = '', ar = array;
	argName=(argName ? argName : 'ar');

	if (ar.length > jS) {
		for (var k = jS; k < ar.length; k++) aS += argName+'['+k+'], ';
		aS = aS.substring(0, aS.length-2);
	}

	return aS;
}

// Places a hook in the correct position in a hook point.
function reOrder(hookPt, fnRef, order) {
	var newPt = new Array(), match, i, j;

	if (!order || typeof order == 'undefined' || typeof order == 'number') return hookPt;

	if (typeof order=='function') {
		if (typeof fnRef=='object') {
			newPt = newPt.concat(fnRef);
		} else {
			newPt[newPt.length++]=fnRef;
		}

		for (i = 0; i < hookPt.length; i++) {
			match = false;
			if (typeof fnRef == 'function' && hookPt[i] == fnRef) {
				continue;
			} else {
				for(j = 0; j < fnRef.length; j++) if (hookPt[i] == fnRef[j]) {
					match = true;
					break;
				}
			}
			if (!match) newPt[newPt.length++] = hookPt[i];
		}

		newPt[newPt.length++] = order;

	} else if (typeof order == 'object') {
		if (typeof fnRef == 'object') {
			newPt = newPt.concat(fnRef);
		} else {
			newPt[newPt.length++] = fnRef;
		}

		for (j = 0; j < hookPt.length; j++) {
			match = false;
			if (typeof fnRef == 'function' && hookPt[j] == fnRef) {
				continue;
			} else {
				for (i = 0; i < fnRef.length; i++) if (hookPt[j] == fnRef[i]) {
					match = true;
					break;
				}
			}
			if (!match) newPt[newPt.length++]=hookPt[j];
		}

		for (i = 0; i < newPt.length; i++) hookPt[i] = newPt[i];
		newPt.length = 0;

		for (j = 0; j < hookPt.length; j++) {
			match = false;
			for (i = 0; i < order.length; i++) {
				if (hookPt[j] == order[i]) {
					match = true;
					break;
				}
			}
			if (!match) newPt[newPt.length++] = hookPt[j];
		}
		newPt = newPt.concat(order);
	}

	hookPt = newPt;

	return hookPt;
}

////////
//  PLUGIN ACTIVATION FUNCTIONS
////////

// Runs plugin functions to set runtime variables.
function setRunTimeVariables(){
	if (typeof runTime != 'undefined' && runTime.length) {
		for (var k = 0; k < runTime.length; k++) {
			runTime[k]();
		}
	}
}

// Runs plugin functions to parse commands.
function parseCmdLine(pf, i, args) {
	if (typeof cmdLine != 'undefined' && cmdLine.length) {
		for (var k = 0; k < cmdLine.length; k++) {
			var j = cmdLine[k](pf, i, args);
			if (j >- 1) {
				i = j;
				break;
			}
		}
	}

	return i;
}

// Runs plugin functions to do things after parse.
function postParseChecks(pf,args){
	if (typeof postParse != 'undefined' && postParse.length) {
		for (var k = 0; k < postParse.length; k++) {
			if (postParse[k](pf,args)) continue;
			return false;  // end now since have an error
		}
	}
	return true;
}


////////
//  PLUGIN REGISTRATION FUNCTIONS
////////

// Registers commands and creates constants.
function registerCommands(cmdStr) {
	if (typeof cmdStr!='string') return;

	var pM = cmdStr.split(',');
	pms = pms.concat(pM);

	for (var i = 0; i< pM.length; i++) {
		eval(pM[i].toUpperCase()+'='+pmCount++);
	}
}

// Registers no-parameter commands
function registerNoParameterCommands(cmdStr) {
	if (!cmdStr && typeof cmdStr != 'string') return;
	pmt=(!pmt) ? cmdStr : pmt + ',' + cmdStr;
}

// Register a function to hook at a certain point.
function registerHook(fnHookTo, fnRef, hookType, optPm) {
	var hookPt, last = typeof optPm;

	if (fnHookTo == 'plgIn'||fnHookTo == 'postParse') return;
	if (typeof hookPts[fnHookTo] == 'undefined') hookPts[fnHookTo] = new FunctionReference();

	hookPt = hookPts[fnHookTo];

	if (hookType != null) {
		if (hookType == FREPLACE) {
			hookPt.ovload = fnRef;  // replace normal overlib routine
			if (fnHookTo.indexOf('ol_content_') > -1) hookPt.alt[pms[CSSOFF-1-pmStart]]=fnRef;

		} else if (hookType == FBEFORE || hookType == FAFTER) {
			var hookPt=(hookType == 1 ? hookPt.before : hookPt.after);

			if (typeof fnRef == 'object') {
				hookPt = hookPt.concat(fnRef);
			} else {
				hookPt[hookPt.length++] = fnRef;
			}

			if (optPm) hookPt = reOrder(hookPt, fnRef, optPm);

		} else if (hookType == FALTERNATE) {
			if (last=='number') hookPt.alt[pms[optPm-1-pmStart]] = fnRef;
		} else if (hookType == FCHAIN) {
			hookPt = hookPt.chain;
			if (typeof fnRef=='object') hookPt=hookPt.concat(fnRef); // add other functions
			else hookPt[hookPt.length++]=fnRef;
		}

		return;
	}
}

// Register a function that will set runtime variables.
function registerRunTimeFunction(fn) {
	if (isFunction(fn)) {
		if (typeof fn == 'object') {
			runTime = runTime.concat(fn);
		} else {
			runTime[runTime.length++] = fn;
		}
	}
}

// Register a function that will handle command parsing.
function registerCmdLineFunction(fn){
	if (isFunction(fn)) {
		if (typeof fn == 'object') {
			cmdLine = cmdLine.concat(fn);
		} else {
			cmdLine[cmdLine.length++] = fn;
		}
	}
}

// Register a function that does things after command parsing.
function registerPostParseFunction(fn){
	if (isFunction(fn)) {
		if (typeof fn == 'object') {
			postParse = postParse.concat(fn);
		} else {
			postParse[postParse.length++] = fn;
		}
	}
}

////////
//  PLUGIN REGISTRATION FUNCTIONS
////////

// Runs any hooks registered.
function runHook(fnHookTo, hookType) {
	var l = hookPts[fnHookTo], k, rtnVal = null, optPm, arS, ar = runHook.arguments;

	if (hookType == FREPLACE) {
		arS = argToString(ar, 2);

		if (typeof l == 'undefined' || !(l = l.ovload)) rtnVal = eval(fnHookTo+'('+arS+')');
		else rtnVal = eval('l('+arS+')');

	} else if (hookType == FBEFORE || hookType == FAFTER) {
		if (typeof l != 'undefined') {
			l=(hookType == 1 ? l.before : l.after);

			if (l.length) {
				arS = argToString(ar, 2);
				for (var k = 0; k < l.length; k++) eval('l[k]('+arS+')');
			}
		}
	} else if (hookType == FALTERNATE) {
		optPm = ar[2];
		arS = argToString(ar, 3);

		if (typeof l == 'undefined' || (l = l.alt[pms[optPm-1-pmStart]]) == 'undefined') {
			rtnVal = eval(fnHookTo+'('+arS+')');
		} else {
			rtnVal = eval('l('+arS+')');
		}
	} else if (hookType == FCHAIN) {
		arS=argToString(ar,2);
		l=l.chain;

		for (k=l.length; k > 0; k--) if((rtnVal=eval('l[k-1]('+arS+')'))!=void(0)) break;
	}

	return rtnVal;
}

////////
// OBJECT CONSTRUCTORS
////////

// Object for handling hooks.
function FunctionReference() {
	this.ovload = null;
	this.before = new Array();
	this.after = new Array();
	this.alt = new Array();
	this.chain = new Array();
}

// Object for simple access to the overLIB version used.
// Examples: simpleversion:351 major:3 minor:5 revision:1
function Info(version, prerelease) {
	this.version = version;
	this.prerelease = prerelease;

	this.simpleversion = Math.round(this.version*100);
	this.major = parseInt(this.simpleversion / 100);
	this.minor = parseInt(this.simpleversion / 10) - this.major * 10;
	this.revision = parseInt(this.simpleversion) - this.major * 100 - this.minor * 10;
	this.meets = meets;
}

// checks for Core Version required
function meets(reqdVersion) {
	return (!reqdVersion) ? false : this.simpleversion >= Math.round(100*parseFloat(reqdVersion));
}


////////
// STANDARD REGISTRATIONS
////////
registerHook("ol_content_simple", ol_content_simple, FALTERNATE, CSSOFF);
registerHook("ol_content_caption", ol_content_caption, FALTERNATE, CSSOFF);
registerHook("ol_content_background", ol_content_background, FALTERNATE, CSSOFF);
registerHook("ol_content_simple", ol_content_simple, FALTERNATE, CSSCLASS);
registerHook("ol_content_caption", ol_content_caption, FALTERNATE, CSSCLASS);
registerHook("ol_content_background", ol_content_background, FALTERNATE, CSSCLASS);
registerPostParseFunction(checkPositionFlags);
registerHook("hideObject", nbspCleanup, FAFTER);
registerHook("horizontalPlacement", horizontalPlacement, FCHAIN);
registerHook("verticalPlacement", verticalPlacement, FCHAIN);
if (olNs4||(olIe5&&isMac)||olKq) olLoaded=1;
registerNoParameterCommands('sticky,autostatus,autostatuscap,fullhtml,hauto,vauto,closeclick,wrap,followmouse,mouseoff,compatmode');
///////
// ESTABLISH MOUSECAPTURING
///////

// Capture events, alt. diffuses the overlib function.
var olCheckMouseCapture=true;
if ((olNs4 || olNs6 || olIe4)) {
	olMouseCapture();
} else {
	overlib = no_overlib;
	nd = no_overlib;
	ver3fix = true;
}
Date.ext={};Date.ext.util={};Date.ext.util.xPad=function(x,pad,r){if(typeof (r)=="undefined"){r=10}for(;parseInt(x,10)<r&&r>1;r/=10){x=pad.toString()+x}return x.toString()};Date.prototype.locale="en-GB";if(document.getElementsByTagName("html")&&document.getElementsByTagName("html")[0].lang){Date.prototype.locale=document.getElementsByTagName("html")[0].lang}Date.ext.locales={};Date.ext.locales.en={a:["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],A:["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"],b:["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],B:["January","February","March","April","May","June","July","August","September","October","November","December"],c:"%a %d %b %Y %T %Z",p:["AM","PM"],P:["am","pm"],x:"%d/%m/%y",X:"%T"};Date.ext.locales["en-US"]=Date.ext.locales.en;Date.ext.locales["en-US"].c="%a %d %b %Y %r %Z";Date.ext.locales["en-US"].x="%D";Date.ext.locales["en-US"].X="%r";Date.ext.locales["en-GB"]=Date.ext.locales.en;Date.ext.locales["en-AU"]=Date.ext.locales["en-GB"];Date.ext.formats={a:function(d){return Date.ext.locales[d.locale].a[d.getDay()]},A:function(d){return Date.ext.locales[d.locale].A[d.getDay()]},b:function(d){return Date.ext.locales[d.locale].b[d.getMonth()]},B:function(d){return Date.ext.locales[d.locale].B[d.getMonth()]},c:"toLocaleString",C:function(d){return Date.ext.util.xPad(parseInt(d.getFullYear()/100,10),0)},d:["getDate","0"],e:["getDate"," "],g:function(d){return Date.ext.util.xPad(parseInt(Date.ext.util.G(d)/100,10),0)},G:function(d){var y=d.getFullYear();var V=parseInt(Date.ext.formats.V(d),10);var W=parseInt(Date.ext.formats.W(d),10);if(W>V){y++}else{if(W===0&&V>=52){y--}}return y},H:["getHours","0"],I:function(d){var I=d.getHours()%12;return Date.ext.util.xPad(I===0?12:I,0)},j:function(d){var ms=d-new Date(""+d.getFullYear()+"/1/1 GMT");ms+=d.getTimezoneOffset()*60000;var doy=parseInt(ms/60000/60/24,10)+1;return Date.ext.util.xPad(doy,0,100)},m:function(d){return Date.ext.util.xPad(d.getMonth()+1,0)},M:["getMinutes","0"],p:function(d){return Date.ext.locales[d.locale].p[d.getHours()>=12?1:0]},P:function(d){return Date.ext.locales[d.locale].P[d.getHours()>=12?1:0]},S:["getSeconds","0"],u:function(d){var dow=d.getDay();return dow===0?7:dow},U:function(d){var doy=parseInt(Date.ext.formats.j(d),10);var rdow=6-d.getDay();var woy=parseInt((doy+rdow)/7,10);return Date.ext.util.xPad(woy,0)},V:function(d){var woy=parseInt(Date.ext.formats.W(d),10);var dow1_1=(new Date(""+d.getFullYear()+"/1/1")).getDay();var idow=woy+(dow1_1>4||dow1_1<=1?0:1);if(idow==53&&(new Date(""+d.getFullYear()+"/12/31")).getDay()<4){idow=1}else{if(idow===0){idow=Date.ext.formats.V(new Date(""+(d.getFullYear()-1)+"/12/31"))}}return Date.ext.util.xPad(idow,0)},w:"getDay",W:function(d){var doy=parseInt(Date.ext.formats.j(d),10);var rdow=7-Date.ext.formats.u(d);var woy=parseInt((doy+rdow)/7,10);return Date.ext.util.xPad(woy,0,10)},y:function(d){return Date.ext.util.xPad(d.getFullYear()%100,0)},Y:"getFullYear",z:function(d){var o=d.getTimezoneOffset();var H=Date.ext.util.xPad(parseInt(Math.abs(o/60),10),0);var M=Date.ext.util.xPad(o%60,0);return(o>0?"-":"+")+H+M},Z:function(d){return d.toString().replace(/^.*\(([^)]+)\)$/,"$1")},"%":function(d){return"%"}};Date.ext.aggregates={c:"locale",D:"%m/%d/%y",h:"%b",n:"\n",r:"%I:%M:%S %p",R:"%H:%M",t:"\t",T:"%H:%M:%S",x:"locale",X:"locale"};Date.ext.aggregates.z=Date.ext.formats.z(new Date());Date.ext.aggregates.Z=Date.ext.formats.Z(new Date());Date.ext.unsupported={};Date.prototype.strftime=function(fmt){if(!(this.locale in Date.ext.locales)){if(this.locale.replace(/-[a-zA-Z]+$/,"") in Date.ext.locales){this.locale=this.locale.replace(/-[a-zA-Z]+$/,"")}else{this.locale="en-GB"}}var d=this;while(fmt.match(/%[cDhnrRtTxXzZ]/)){fmt=fmt.replace(/%([cDhnrRtTxXzZ])/g,function(m0,m1){var f=Date.ext.aggregates[m1];return(f=="locale"?Date.ext.locales[d.locale][m1]:f)})}var str=fmt.replace(/%([aAbBCdegGHIjmMpPSuUVwWyY%])/g,function(m0,m1){var f=Date.ext.formats[m1];if(typeof (f)=="string"){return d[f]()}else{if(typeof (f)=="function"){return f.call(d,d)}else{if(typeof (f)=="object"&&typeof (f[0])=="string"){return Date.ext.util.xPad(d[f[0]](),f[1])}else{return m1}}}});d=null;return str};
