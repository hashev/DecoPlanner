(function dartProgram(){function copyProperties(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
b[q]=a[q]}}function mixinPropertiesHard(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
if(!b.hasOwnProperty(q)){b[q]=a[q]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var s=function(){}
s.prototype={p:{}}
var r=new s()
if(!(Object.getPrototypeOf(r)&&Object.getPrototypeOf(r).p===s.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var q=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(q))return true}}catch(p){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var s=Object.create(b.prototype)
copyProperties(a.prototype,s)
a.prototype=s}}function inheritMany(a,b){for(var s=0;s<b.length;s++){inherit(b[s],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){var r=d()
if(a[b]!==s){A.kO(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.k(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.fH(b)
return new s(c,this)}:function(){if(s===null)s=A.fH(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.fH(a).prototype
return s}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var s=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var r=staticTearOffGetter(s)
a[b]=r}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var s=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var r=instanceTearOffGetter(c,s)
a[b]=r}function setOrUpdateInterceptorsByTag(a){var s=v.interceptorsByTag
if(!s){v.interceptorsByTag=a
return}copyProperties(a,s)}function setOrUpdateLeafTags(a){var s=v.leafTags
if(!s){v.leafTags=a
return}copyProperties(a,s)}function updateTypes(a){var s=v.types
var r=s.length
s.push.apply(s,a)
return r}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var s=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},r=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:s(0,0,null,["$0"],0),_instance_1u:s(0,1,null,["$1"],0),_instance_2u:s(0,2,null,["$2"],0),_instance_0i:s(1,0,null,["$0"],0),_instance_1i:s(1,1,null,["$1"],0),_instance_2i:s(1,2,null,["$2"],0),_static_0:r(0,null,["$0"],0),_static_1:r(1,null,["$1"],0),_static_2:r(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
fN(a,b,c,d){return{i:a,p:b,e:c,x:d}},
fJ(a){var s,r,q,p,o,n=a[v.dispatchPropertyName]
if(n==null)if($.fK==null){A.kC()
n=a[v.dispatchPropertyName]}if(n!=null){s=n.p
if(!1===s)return n.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return n.i
if(n.e===r)throw A.a(A.hl("Return interceptor for "+A.u(s(a,n))))}q=a.constructor
if(q==null)p=null
else{o=$.eh
if(o==null)o=$.eh=v.getIsolateTag("_$dart_js")
p=q[o]}if(p!=null)return p
p=A.kG(a)
if(p!=null)return p
if(typeof a=="function")return B.aK
s=Object.getPrototypeOf(a)
if(s==null)return B.K
if(s===Object.prototype)return B.K
if(typeof q=="function"){o=$.eh
if(o==null)o=$.eh=v.getIsolateTag("_$dart_js")
Object.defineProperty(q,o,{value:B.w,enumerable:false,writable:true,configurable:true})
return B.w}return B.w},
iF(a,b){if(a<0||a>4294967295)throw A.a(A.aK(a,0,4294967295,"length",null))
return J.iG(new Array(a),b)},
h7(a,b){if(a<0)throw A.a(A.aW("Length must be a non-negative integer: "+a,null))
return A.k(new Array(a),b.i("q<0>"))},
b0(a,b){if(a<0)throw A.a(A.aW("Length must be a non-negative integer: "+a,null))
return A.k(new Array(a),b.i("q<0>"))},
iG(a,b){var s=A.k(a,b.i("q<0>"))
s.$flags=1
return s},
ay(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.b1.prototype
return J.bW.prototype}if(typeof a=="string")return J.aE.prototype
if(a==null)return J.b2.prototype
if(typeof a=="boolean")return J.bV.prototype
if(Array.isArray(a))return J.q.prototype
if(typeof a!="object"){if(typeof a=="function")return J.af.prototype
if(typeof a=="symbol")return J.b6.prototype
if(typeof a=="bigint")return J.b4.prototype
return a}if(a instanceof A.h)return a
return J.fJ(a)},
hU(a){if(typeof a=="string")return J.aE.prototype
if(a==null)return a
if(Array.isArray(a))return J.q.prototype
if(typeof a!="object"){if(typeof a=="function")return J.af.prototype
if(typeof a=="symbol")return J.b6.prototype
if(typeof a=="bigint")return J.b4.prototype
return a}if(a instanceof A.h)return a
return J.fJ(a)},
eU(a){if(a==null)return a
if(Array.isArray(a))return J.q.prototype
if(typeof a!="object"){if(typeof a=="function")return J.af.prototype
if(typeof a=="symbol")return J.b6.prototype
if(typeof a=="bigint")return J.b4.prototype
return a}if(a instanceof A.h)return a
return J.fJ(a)},
a0(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.ay(a).G(a,b)},
fR(a,b){return J.eU(a).H(a,b)},
a1(a){return J.ay(a).gq(a)},
ih(a){return J.eU(a).gaQ(a)},
bH(a){return J.eU(a).gn(a)},
ii(a){return J.hU(a).gm(a)},
ij(a){return J.ay(a).gt(a)},
aA(a,b,c){return J.eU(a).aR(a,b,c)},
bI(a){return J.ay(a).j(a)},
bT:function bT(){},
bV:function bV(){},
b2:function b2(){},
b5:function b5(){},
ah:function ah(){},
cb:function cb(){},
bj:function bj(){},
af:function af(){},
b4:function b4(){},
b6:function b6(){},
q:function q(a){this.$ti=a},
bU:function bU(){},
db:function db(a){this.$ti=a},
aB:function aB(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
b3:function b3(){},
b1:function b1(){},
bW:function bW(){},
aE:function aE(){}},A={fj:function fj(){},
iq(a,b,c){if(t.O.b(a))return new A.bn(a,b.i("@<0>").C(c).i("bn<1,2>"))
return new A.an(a,b.i("@<0>").C(c).i("an<1,2>"))},
iH(a){return new A.ag("Field '"+a+"' has been assigned during initialization.")},
iJ(a){return new A.ag("Field '"+a+"' has not been initialized.")},
iI(a){return new A.ag("Field '"+a+"' has already been initialized.")},
ab(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
dw(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
fG(a,b,c){return a},
fM(a){var s,r
for(s=$.av.length,r=0;r<s;++r)if(a===$.av[r])return!0
return!1},
fh(){return new A.bg("No element")},
aM:function aM(){},
bM:function bM(a,b){this.a=a
this.$ti=b},
an:function an(a,b){this.a=a
this.$ti=b},
bn:function bn(a,b){this.a=a
this.$ti=b},
ao:function ao(a,b){this.a=a
this.$ti=b},
d0:function d0(a,b){this.a=a
this.b=b},
ag:function ag(a){this.a=a},
ds:function ds(){},
i:function i(){},
H:function H(){},
bi:function bi(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
aF:function aF(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
E:function E(a,b,c){this.a=a
this.b=b
this.$ti=c},
bl:function bl(a,b,c){this.a=a
this.b=b
this.$ti=c},
co:function co(a,b){this.a=a
this.b=b},
b_:function b_(){},
i4(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
lc(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.p.b(a)},
u(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.bI(a)
return s},
cd(a){var s,r=$.hg
if(r==null)r=$.hg=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
ce(a){var s,r,q,p
if(a instanceof A.h)return A.P(A.aU(a),null)
s=J.ay(a)
if(s===B.aJ||s===B.aL||t.B.b(a)){r=B.x(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.P(A.aU(a),null)},
hh(a){var s,r,q
if(a==null||typeof a=="number"||A.at(a))return J.bI(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.ap)return a.j(0)
if(a instanceof A.bt)return a.aB(!0)
s=$.ig()
for(r=0;r<1;++r){q=s[r].cf(a)
if(q!=null)return q}return"Instance of '"+A.ce(a)+"'"},
iS(){return Date.now()},
iU(){var s,r
if($.dp!==0)return
$.dp=1000
if(typeof window=="undefined")return
s=window
if(s==null)return
if(!!s.dartUseDateNowForTicks)return
r=s.performance
if(r==null)return
if(typeof r.now!="function")return
$.dp=1e6
$.fq=new A.dn(r)},
K(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.az(s,10)|55296)>>>0,s&1023|56320)}throw A.a(A.aK(a,0,1114111,null,null))},
iT(a){var s=a.$thrownJsError
if(s==null)return null
return A.aT(s)},
iV(a,b){var s
if(a.$thrownJsError==null){s=new Error()
A.z(a,s)
a.$thrownJsError=s
s.stack=b.j(0)}},
kn(a){return new A.a7(!0,a,null,null)},
hS(a){return a},
a(a){return A.z(a,new Error())},
z(a,b){var s
if(a==null)a=new A.ac()
b.dartException=a
s=A.kR
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
kR(){return J.bI(this.dartException)},
j(a,b){throw A.z(a,b==null?new Error():b)},
kQ(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.j(A.jL(a,b,c),s)},
jL(a,b,c){var s,r,q,p,o,n,m,l,k
if(typeof b=="string")s=b
else{r="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
q=r.length
p=b
if(p>q){c=p/q|0
p%=q}s=r[p]}o=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
n=t.j.b(a)?"list":"ByteData"
m=a.$flags|0
l="a "
if((m&4)!==0)k="constant "
else if((m&2)!==0){k="unmodifiable "
l="an "}else k=(m&1)!==0?"fixed-length ":""
return new A.bk("'"+s+"': Cannot "+o+" "+l+k+n)},
cK(a){throw A.a(A.a2(a))},
ad(a){var s,r,q,p,o,n
a=A.kL(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.k([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.dE(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
dF(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
hk(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
fk(a,b){var s=b==null,r=s?null:b.method
return new A.bX(a,r,s?null:b.receiver)},
a_(a){if(a==null)return new A.di(a)
if(a instanceof A.aZ)return A.am(a,a.a)
if(typeof a!=="object")return a
if("dartException" in a)return A.am(a,a.dartException)
return A.kl(a)},
am(a,b){if(t.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
kl(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.az(r,16)&8191)===10)switch(q){case 438:return A.am(a,A.fk(A.u(s)+" (Error "+q+")",null))
case 445:case 5007:A.u(s)
return A.am(a,new A.bc())}}if(a instanceof TypeError){p=$.i5()
o=$.i6()
n=$.i7()
m=$.i8()
l=$.ib()
k=$.ic()
j=$.ia()
$.i9()
i=$.ie()
h=$.id()
g=p.F(s)
if(g!=null)return A.am(a,A.fk(s,g))
else{g=o.F(s)
if(g!=null){g.method="call"
return A.am(a,A.fk(s,g))}else if(n.F(s)!=null||m.F(s)!=null||l.F(s)!=null||k.F(s)!=null||j.F(s)!=null||m.F(s)!=null||i.F(s)!=null||h.F(s)!=null)return A.am(a,new A.bc())}return A.am(a,new A.ck(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.bf()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.am(a,new A.a7(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.bf()
return a},
aT(a){var s
if(a instanceof A.aZ)return a.b
if(a==null)return new A.bx(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.bx(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
hX(a){if(a==null)return J.a1(a)
if(typeof a=="object")return A.cd(a)
return J.a1(a)},
kw(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.M(0,a[s],a[r])}return b},
jV(a,b,c,d,e,f){switch(b){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.a(new A.e6("Unsupported number of arguments for wrapped closure"))},
eQ(a,b){var s=a.$identity
if(!!s)return s
s=A.ks(a,b)
a.$identity=s
return s},
ks(a,b){var s
switch(b){case 0:s=a.$0
break
case 1:s=a.$1
break
case 2:s=a.$2
break
case 3:s=a.$3
break
case 4:s=a.$4
break
default:s=null}if(s!=null)return s.bind(a)
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.jV)},
iv(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.dt().constructor.prototype):Object.create(new A.aX(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.h0(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.ir(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.h0(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
ir(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.a("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.il)}throw A.a("Error in functionType of tearoff")},
is(a,b,c,d){var s=A.fX
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
h0(a,b,c,d){if(c)return A.iu(a,b,d)
return A.is(b.length,d,a,b)},
it(a,b,c,d){var s=A.fX,r=A.im
switch(b?-1:a){case 0:throw A.a(new A.ci("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
iu(a,b,c){var s,r
if($.fV==null)$.fV=A.fU("interceptor")
if($.fW==null)$.fW=A.fU("receiver")
s=b.length
r=A.it(s,c,a,b)
return r},
fH(a){return A.iv(a)},
il(a,b){return A.bD(v.typeUniverse,A.aU(a.a),b)},
fX(a){return a.a},
im(a){return a.b},
fU(a){var s,r,q,p=new A.aX("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.a(A.aW("Field name "+a+" not found.",null))},
ky(a){return v.getIsolateTag(a)},
kG(a){var s,r,q,p,o,n=$.hV.$1(a),m=$.eR[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eY[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=$.hL.$2(a,n)
if(q!=null){m=$.eR[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eY[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.f2(s)
$.eR[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.eY[n]=s
return s}if(p==="-"){o=A.f2(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.hY(a,s)
if(p==="*")throw A.a(A.hl(n))
if(v.leafTags[n]===true){o=A.f2(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.hY(a,s)},
hY(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.fN(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
f2(a){return J.fN(a,!1,null,!!a.$iO)},
kI(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.f2(s)
else return J.fN(s,c,null,null)},
kC(){if(!0===$.fK)return
$.fK=!0
A.kD()},
kD(){var s,r,q,p,o,n,m,l
$.eR=Object.create(null)
$.eY=Object.create(null)
A.kB()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.i1.$1(o)
if(n!=null){m=A.kI(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
kB(){var s,r,q,p,o,n,m=B.M()
m=A.aS(B.N,A.aS(B.O,A.aS(B.y,A.aS(B.y,A.aS(B.P,A.aS(B.Q,A.aS(B.R(B.x),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.hV=new A.eV(p)
$.hL=new A.eW(o)
$.i1=new A.eX(n)},
aS(a,b){return a(b)||b},
ji(a,b){var s
for(s=0;s<a.length;++s)if(!J.a0(a[s],b[s]))return!1
return!0},
ku(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
kL(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
cB:function cB(a,b){this.a=a
this.b=b},
bu:function bu(a,b){this.a=a
this.b=b},
bv:function bv(a,b){this.a=a
this.b=b},
cC:function cC(a,b,c){this.a=a
this.b=b
this.c=c},
a6:function a6(a){this.a=a},
dn:function dn(a){this.a=a},
be:function be(){},
dE:function dE(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bc:function bc(){},
bX:function bX(a,b,c){this.a=a
this.b=b
this.c=c},
ck:function ck(a){this.a=a},
di:function di(a){this.a=a},
aZ:function aZ(a,b){this.a=a
this.b=b},
bx:function bx(a){this.a=a
this.b=null},
ap:function ap(){},
d2:function d2(){},
d3:function d3(){},
dx:function dx(){},
dt:function dt(){},
aX:function aX(a,b){this.a=a
this.b=b},
ci:function ci(a){this.a=a},
a9:function a9(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
dc:function dc(a){this.a=a},
dg:function dg(a,b){this.a=a
this.b=b
this.c=null},
aq:function aq(a,b){this.a=a
this.$ti=b},
c_:function c_(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
C:function C(a,b){this.a=a
this.$ti=b},
bZ:function bZ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
eV:function eV(a){this.a=a},
eW:function eW(a){this.a=a},
eX:function eX(a){this.a=a},
bt:function bt(){},
cy:function cy(){},
cz:function cz(){},
cA:function cA(){},
kO(a){throw A.z(A.iH(a),new Error())},
r(){throw A.z(A.iJ(""),new Error())},
kP(){throw A.z(A.iI(""),new Error())},
j9(){var s=new A.e4()
return s.b=s},
e4:function e4(){this.b=null},
aG:function aG(){},
ba:function ba(){},
c0:function c0(){},
aH:function aH(){},
b8:function b8(){},
b9:function b9(){},
c1:function c1(){},
c2:function c2(){},
c3:function c3(){},
c4:function c4(){},
c5:function c5(){},
c6:function c6(){},
c7:function c7(){},
bb:function bb(){},
c8:function c8(){},
bp:function bp(){},
bq:function bq(){},
br:function br(){},
bs:function bs(){},
fs(a,b){var s=b.c
return s==null?b.c=A.bB(a,"ae",[b.x]):s},
hi(a){var s=a.w
if(s===6||s===7)return A.hi(a.x)
return s===11||s===12},
iX(a){return a.as},
kJ(a,b){var s,r=b.length
for(s=0;s<r;++s)if(!a[s].b(b[s]))return!1
return!0},
ax(a){return A.es(v.typeUniverse,a,!1)},
au(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.au(a1,s,a3,a4)
if(r===s)return a2
return A.hw(a1,r,!0)
case 7:s=a2.x
r=A.au(a1,s,a3,a4)
if(r===s)return a2
return A.hv(a1,r,!0)
case 8:q=a2.y
p=A.aR(a1,q,a3,a4)
if(p===q)return a2
return A.bB(a1,a2.x,p)
case 9:o=a2.x
n=A.au(a1,o,a3,a4)
m=a2.y
l=A.aR(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.fy(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.aR(a1,j,a3,a4)
if(i===j)return a2
return A.hx(a1,k,i)
case 11:h=a2.x
g=A.au(a1,h,a3,a4)
f=a2.y
e=A.ki(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.hu(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.aR(a1,d,a3,a4)
o=a2.x
n=A.au(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.fz(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.a(A.bK("Attempted to substitute unexpected RTI kind "+a0))}},
aR(a,b,c,d){var s,r,q,p,o=b.length,n=A.et(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.au(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
kj(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.et(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.au(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
ki(a,b,c,d){var s,r=b.a,q=A.aR(a,r,c,d),p=b.b,o=A.aR(a,p,c,d),n=b.c,m=A.kj(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.cu()
s.a=q
s.b=o
s.c=m
return s},
k(a,b){a[v.arrayRti]=b
return a},
hT(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.kA(s)
return a.$S()}return null},
kE(a,b){var s
if(A.hi(b))if(a instanceof A.ap){s=A.hT(a)
if(s!=null)return s}return A.aU(a)},
aU(a){if(a instanceof A.h)return A.Y(a)
if(Array.isArray(a))return A.R(a)
return A.fA(J.ay(a))},
R(a){var s=a[v.arrayRti],r=t.b
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
Y(a){var s=a.$ti
return s!=null?s:A.fA(a)},
fA(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.jS(a,s)},
jS(a,b){var s=a instanceof A.ap?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.jr(v.typeUniverse,s.name)
b.$ccache=r
return r},
kA(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.es(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
kz(a){return A.aw(A.Y(a))},
fE(a){var s
if(a instanceof A.bt)return A.kv(a.$r,a.V())
s=a instanceof A.ap?A.hT(a):null
if(s!=null)return s
if(t.R.b(a))return J.ij(a).a
if(Array.isArray(a))return A.R(a)
return A.aU(a)},
aw(a){var s=a.r
return s==null?a.r=new A.er(a):s},
kv(a,b){var s,r,q=b,p=q.length
if(p===0)return t.F
s=A.bD(v.typeUniverse,A.fE(q[0]),"@<0>")
for(r=1;r<p;++r)s=A.hy(v.typeUniverse,s,A.fE(q[r]))
return A.bD(v.typeUniverse,s,a)},
Z(a){return A.aw(A.es(v.typeUniverse,a,!1))},
jR(a){var s=this
s.b=A.kg(s)
return s.b(a)},
kg(a){var s,r,q,p
if(a===t.K)return A.k0
if(A.az(a))return A.k4
s=a.w
if(s===6)return A.jP
if(s===1)return A.hG
if(s===7)return A.jW
r=A.kf(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.az)){a.f="$i"+q
if(q==="f")return A.jZ
if(a===t.m)return A.jY
return A.k3}}else if(s===10){p=A.ku(a.x,a.y)
return p==null?A.hG:p}return A.jN},
kf(a){if(a.w===8){if(a===t.S)return A.cI
if(a===t.i||a===t.H)return A.k_
if(a===t.N)return A.k2
if(a===t.y)return A.at}return null},
jQ(a){var s=this,r=A.jM
if(A.az(s))r=A.jD
else if(s===t.K)r=A.jB
else if(A.aV(s)){r=A.jO
if(s===t.a3)r=A.jx
else if(s===t.x)r=A.jC
else if(s===t.u)r=A.ju
else if(s===t.ae)r=A.jA
else if(s===t.dd)r=A.jw
else if(s===t.t)r=A.jz}else if(s===t.S)r=A.cG
else if(s===t.N)r=A.eE
else if(s===t.y)r=A.jt
else if(s===t.H)r=A.eD
else if(s===t.i)r=A.jv
else if(s===t.m)r=A.jy
s.a=r
return s.a(a)},
jN(a){var s=this
if(a==null)return A.aV(s)
return A.kF(v.typeUniverse,A.kE(a,s),s)},
jP(a){if(a==null)return!0
return this.x.b(a)},
k3(a){var s,r=this
if(a==null)return A.aV(r)
s=r.f
if(a instanceof A.h)return!!a[s]
return!!J.ay(a)[s]},
jZ(a){var s,r=this
if(a==null)return A.aV(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.h)return!!a[s]
return!!J.ay(a)[s]},
jY(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.h)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
hF(a){if(typeof a=="object"){if(a instanceof A.h)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
jM(a){var s=this
if(a==null){if(A.aV(s))return a}else if(s.b(a))return a
throw A.z(A.hC(a,s),new Error())},
jO(a){var s=this
if(a==null||s.b(a))return a
throw A.z(A.hC(a,s),new Error())},
hC(a,b){return new A.bz("TypeError: "+A.hn(a,A.P(b,null)))},
hn(a,b){return A.bR(a)+": type '"+A.P(A.fE(a),null)+"' is not a subtype of type '"+b+"'"},
Q(a,b){return new A.bz("TypeError: "+A.hn(a,b))},
jW(a){var s=this
return s.x.b(a)||A.fs(v.typeUniverse,s).b(a)},
k0(a){return a!=null},
jB(a){if(a!=null)return a
throw A.z(A.Q(a,"Object"),new Error())},
k4(a){return!0},
jD(a){return a},
hG(a){return!1},
at(a){return!0===a||!1===a},
jt(a){if(!0===a)return!0
if(!1===a)return!1
throw A.z(A.Q(a,"bool"),new Error())},
ju(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.z(A.Q(a,"bool?"),new Error())},
jv(a){if(typeof a=="number")return a
throw A.z(A.Q(a,"double"),new Error())},
jw(a){if(typeof a=="number")return a
if(a==null)return a
throw A.z(A.Q(a,"double?"),new Error())},
cI(a){return typeof a=="number"&&Math.floor(a)===a},
cG(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.z(A.Q(a,"int"),new Error())},
jx(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.z(A.Q(a,"int?"),new Error())},
k_(a){return typeof a=="number"},
eD(a){if(typeof a=="number")return a
throw A.z(A.Q(a,"num"),new Error())},
jA(a){if(typeof a=="number")return a
if(a==null)return a
throw A.z(A.Q(a,"num?"),new Error())},
k2(a){return typeof a=="string"},
eE(a){if(typeof a=="string")return a
throw A.z(A.Q(a,"String"),new Error())},
jC(a){if(typeof a=="string")return a
if(a==null)return a
throw A.z(A.Q(a,"String?"),new Error())},
jy(a){if(A.hF(a))return a
throw A.z(A.Q(a,"JSObject"),new Error())},
jz(a){if(a==null)return a
if(A.hF(a))return a
throw A.z(A.Q(a,"JSObject?"),new Error())},
hJ(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.P(a[q],b)
return s},
ka(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.hJ(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.P(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
hD(a1,a2,a3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=", ",a0=null
if(a3!=null){s=a3.length
if(a2==null)a2=A.k([],t.s)
else a0=a2.length
r=a2.length
for(q=s;q>0;--q)a2.push("T"+(r+q))
for(p=t.X,o="<",n="",q=0;q<s;++q,n=a){o=o+n+a2[a2.length-1-q]
m=a3[q]
l=m.w
if(!(l===2||l===3||l===4||l===5||m===p))o+=" extends "+A.P(m,a2)}o+=">"}else o=""
p=a1.x
k=a1.y
j=k.a
i=j.length
h=k.b
g=h.length
f=k.c
e=f.length
d=A.P(p,a2)
for(c="",b="",q=0;q<i;++q,b=a)c+=b+A.P(j[q],a2)
if(g>0){c+=b+"["
for(b="",q=0;q<g;++q,b=a)c+=b+A.P(h[q],a2)
c+="]"}if(e>0){c+=b+"{"
for(b="",q=0;q<e;q+=3,b=a){c+=b
if(f[q+1])c+="required "
c+=A.P(f[q+2],a2)+" "+f[q]}c+="}"}if(a0!=null){a2.toString
a2.length=a0}return o+"("+c+") => "+d},
P(a,b){var s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){s=a.x
r=A.P(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(m===7)return"FutureOr<"+A.P(a.x,b)+">"
if(m===8){p=A.kk(a.x)
o=a.y
return o.length>0?p+("<"+A.hJ(o,b)+">"):p}if(m===10)return A.ka(a,b)
if(m===11)return A.hD(a,b,null)
if(m===12)return A.hD(a.x,b,a.y)
if(m===13){n=a.x
return b[b.length-1-n]}return"?"},
kk(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
js(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
jr(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.es(a,b,!1)
else if(typeof m=="number"){s=m
r=A.bC(a,5,"#")
q=A.et(s)
for(p=0;p<s;++p)q[p]=r
o=A.bB(a,b,q)
n[b]=o
return o}else return m},
jq(a,b){return A.hz(a.tR,b)},
jp(a,b){return A.hz(a.eT,b)},
es(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.hr(A.hp(a,null,b,!1))
r.set(b,s)
return s},
bD(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.hr(A.hp(a,b,c,!0))
q.set(c,r)
return r},
hy(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.fy(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
al(a,b){b.a=A.jQ
b.b=A.jR
return b},
bC(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.X(null,null)
s.w=b
s.as=c
r=A.al(a,s)
a.eC.set(c,r)
return r},
hw(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.jn(a,b,r,c)
a.eC.set(r,s)
return s},
jn(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.az(b))if(!(b===t.P||b===t.T))if(s!==6)r=s===7&&A.aV(b.x)
if(r)return b
else if(s===1)return t.P}q=new A.X(null,null)
q.w=6
q.x=b
q.as=c
return A.al(a,q)},
hv(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.jl(a,b,r,c)
a.eC.set(r,s)
return s},
jl(a,b,c,d){var s,r
if(d){s=b.w
if(A.az(b)||b===t.K)return b
else if(s===1)return A.bB(a,"ae",[b])
else if(b===t.P||b===t.T)return t.r}r=new A.X(null,null)
r.w=7
r.x=b
r.as=c
return A.al(a,r)},
jo(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.X(null,null)
s.w=13
s.x=b
s.as=q
r=A.al(a,s)
a.eC.set(q,r)
return r},
bA(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
jk(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
bB(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.bA(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.X(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.al(a,r)
a.eC.set(p,q)
return q},
fy(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.bA(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.X(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.al(a,o)
a.eC.set(q,n)
return n},
hx(a,b,c){var s,r,q="+"+(b+"("+A.bA(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.X(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.al(a,s)
a.eC.set(q,r)
return r},
hu(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.bA(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.bA(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.jk(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.X(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.al(a,p)
a.eC.set(r,o)
return o},
fz(a,b,c,d){var s,r=b.as+("<"+A.bA(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.jm(a,b,c,r,d)
a.eC.set(r,s)
return s},
jm(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.et(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.au(a,b,r,0)
m=A.aR(a,c,r,0)
return A.fz(a,n,m,c!==m)}}l=new A.X(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.al(a,l)},
hp(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
hr(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.jd(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.hq(a,r,l,k,!1)
else if(q===46)r=A.hq(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.as(a.u,a.e,k.pop()))
break
case 94:k.push(A.jo(a.u,k.pop()))
break
case 35:k.push(A.bC(a.u,5,"#"))
break
case 64:k.push(A.bC(a.u,2,"@"))
break
case 126:k.push(A.bC(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.jf(a,k)
break
case 38:A.je(a,k)
break
case 63:p=a.u
k.push(A.hw(p,A.as(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.hv(p,A.as(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.jc(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.hs(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.jh(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-2)
break
case 43:n=l.indexOf("(",r)
k.push(l.substring(r,n))
k.push(-4)
k.push(a.p)
a.p=k.length
r=n+1
break
default:throw"Bad character "+q}}}m=k.pop()
return A.as(a.u,a.e,m)},
jd(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
hq(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.js(s,o.x)[p]
if(n==null)A.j('No "'+p+'" in "'+A.iX(o)+'"')
d.push(A.bD(s,o,n))}else d.push(p)
return m},
jf(a,b){var s,r=a.u,q=A.ho(a,b),p=b.pop()
if(typeof p=="string")b.push(A.bB(r,p,q))
else{s=A.as(r,a.e,p)
switch(s.w){case 11:b.push(A.fz(r,s,q,a.n))
break
default:b.push(A.fy(r,s,q))
break}}},
jc(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.ho(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.as(p,a.e,o)
q=new A.cu()
q.a=s
q.b=n
q.c=m
b.push(A.hu(p,r,q))
return
case-4:b.push(A.hx(p,b.pop(),s))
return
default:throw A.a(A.bK("Unexpected state under `()`: "+A.u(o)))}},
je(a,b){var s=b.pop()
if(0===s){b.push(A.bC(a.u,1,"0&"))
return}if(1===s){b.push(A.bC(a.u,4,"1&"))
return}throw A.a(A.bK("Unexpected extended operation "+A.u(s)))},
ho(a,b){var s=b.splice(a.p)
A.hs(a.u,a.e,s)
a.p=b.pop()
return s},
as(a,b,c){if(typeof c=="string")return A.bB(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.jg(a,b,c)}else return c},
hs(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.as(a,b,c[s])},
jh(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.as(a,b,c[s])},
jg(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.a(A.bK("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.a(A.bK("Bad index "+c+" for "+b.j(0)))},
kF(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.B(a,b,null,c,null)
r.set(c,s)}return s},
B(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.az(d))return!0
s=b.w
if(s===4)return!0
if(A.az(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.B(a,c[b.x],c,d,e))return!0
q=d.w
p=t.P
if(b===p||b===t.T){if(q===7)return A.B(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.B(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.B(a,b.x,c,d,e))return!1
return A.B(a,A.fs(a,b),c,d,e)}if(s===6)return A.B(a,p,c,d,e)&&A.B(a,b.x,c,d,e)
if(q===7){if(A.B(a,b,c,d.x,e))return!0
return A.B(a,b,c,A.fs(a,d),e)}if(q===6)return A.B(a,b,c,p,e)||A.B(a,b,c,d.x,e)
if(r)return!1
p=s!==11
if((!p||s===12)&&d===t.Y)return!0
o=s===10
if(o&&d===t.V)return!0
if(q===12){if(b===t.g)return!0
if(s!==12)return!1
n=b.y
m=d.y
l=n.length
if(l!==m.length)return!1
c=c==null?n:n.concat(c)
e=e==null?m:m.concat(e)
for(k=0;k<l;++k){j=n[k]
i=m[k]
if(!A.B(a,j,c,i,e)||!A.B(a,i,e,j,c))return!1}return A.hE(a,b.x,c,d.x,e)}if(q===11){if(b===t.g)return!0
if(p)return!1
return A.hE(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.jX(a,b,c,d,e)}if(o&&q===10)return A.k1(a,b,c,d,e)
return!1},
hE(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.B(a3,a4.x,a5,a6.x,a7))return!1
s=a4.y
r=a6.y
q=s.a
p=r.a
o=q.length
n=p.length
if(o>n)return!1
m=n-o
l=s.b
k=r.b
j=l.length
i=k.length
if(o+j<n+i)return!1
for(h=0;h<o;++h){g=q[h]
if(!A.B(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.B(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.B(a3,k[h],a7,g,a5))return!1}f=s.c
e=r.c
d=f.length
c=e.length
for(b=0,a=0;a<c;a+=3){a0=e[a]
for(;;){if(b>=d)return!1
a1=f[b]
b+=3
if(a0<a1)return!1
a2=f[b-2]
if(a1<a0){if(a2)return!1
continue}g=e[a+1]
if(a2&&!g)return!1
g=f[b-1]
if(!A.B(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
jX(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.bD(a,b,r[o])
return A.hA(a,p,null,c,d.y,e)}return A.hA(a,b.y,null,c,d.y,e)},
hA(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.B(a,b[s],d,e[s],f))return!1
return!0},
k1(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.B(a,r[s],c,q[s],e))return!1
return!0},
aV(a){var s=a.w,r=!0
if(!(a===t.P||a===t.T))if(!A.az(a))if(s!==6)r=s===7&&A.aV(a.x)
return r},
az(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.X},
hz(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
et(a){return a>0?new Array(a):v.typeUniverse.sEA},
X:function X(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cu:function cu(){this.c=this.b=this.a=null},
er:function er(a){this.a=a},
ct:function ct(){},
bz:function bz(a){this.a=a},
j5(){var s,r,q
if(self.scheduleImmediate!=null)return A.ko()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.eQ(new A.e1(s),1)).observe(r,{childList:true})
return new A.e0(s,r,q)}else if(self.setImmediate!=null)return A.kp()
return A.kq()},
j6(a){self.scheduleImmediate(A.eQ(new A.e2(a),0))},
j7(a){self.setImmediate(A.eQ(new A.e3(a),0))},
j8(a){A.jj(0,a)},
jj(a,b){var s=new A.ep()
s.b9(a,b)
return s},
k7(a){return new A.cq(new A.F($.x,a.i("F<0>")),a.i("cq<0>"))},
jH(a,b){a.$2(0,null)
b.b=!0
return b.a},
jE(a,b){A.jI(a,b)},
jG(a,b){b.ah(a)},
jF(a,b){b.aH(A.a_(a),A.aT(a))},
jI(a,b){var s,r,q=new A.eF(b),p=new A.eG(b)
if(a instanceof A.F)a.aA(q,p,t.z)
else{s=t.z
if(a instanceof A.F)a.aW(q,p,s)
else{r=new A.F($.x,t.e)
r.a=8
r.c=a
r.aA(q,p,s)}}},
km(a){var s=function(b,c){return function(d,e){while(true){try{b(d,e)
break}catch(r){e=r
d=c}}}}(a,1)
return $.x.aU(new A.eO(s))},
ht(a,b,c){return 0},
fd(a){var s
if(t.C.b(a)){s=a.gR()
if(s!=null)return s}return B.U},
jT(a,b){if($.x===B.h)return null
return null},
jU(a,b){if($.x!==B.h)A.jT(a,b)
if(t.C.b(a))A.iV(a,b)
return new A.S(a,b)},
fw(a,b,c){var s,r,q,p={},o=p.a=a
while(s=o.a,(s&4)!==0){o=o.c
p.a=o}if(o===b){s=A.iY()
b.a4(new A.S(new A.a7(!0,o,null,"Cannot complete a future with itself"),s))
return}r=b.a&1
s=o.a=s|r
if((s&24)===0){q=b.c
b.a=b.a&1|4
b.c=o
o.aw(q)
return}if(!c)if(b.c==null)o=(s&16)===0||r!==0
else o=!1
else o=!0
if(o){q=b.W()
b.T(p.a)
A.aO(b,q)
return}b.a^=2
A.cJ(null,null,b.b,new A.ea(p,b))},
aO(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g={},f=g.a=a
for(;;){s={}
r=f.a
q=(r&16)===0
p=!q
if(b==null){if(p&&(r&1)===0){f=f.c
A.fC(f.a,f.b)}return}s.a=b
o=b.a
for(f=b;o!=null;f=o,o=n){f.a=null
A.aO(g.a,f)
s.a=o
n=o.a}r=g.a
m=r.c
s.b=p
s.c=m
if(q){l=f.c
l=(l&1)!==0||(l&15)===8}else l=!0
if(l){k=f.b.b
if(p){r=r.b===k
r=!(r||r)}else r=!1
if(r){A.fC(m.a,m.b)
return}j=$.x
if(j!==k)$.x=k
else j=null
f=f.c
if((f&15)===8)new A.ee(s,g,p).$0()
else if(q){if((f&1)!==0)new A.ed(s,m).$0()}else if((f&2)!==0)new A.ec(g,s).$0()
if(j!=null)$.x=j
f=s.c
if(f instanceof A.F){r=s.a.$ti
r=r.i("ae<2>").b(f)||!r.y[1].b(f)}else r=!1
if(r){i=s.a.b
if((f.a&24)!==0){h=i.c
i.c=null
b=i.X(h)
i.a=f.a&30|i.a&1
i.c=f.c
g.a=f
continue}else A.fw(f,i,!0)
return}}i=s.a.b
h=i.c
i.c=null
b=i.X(h)
f=s.b
r=s.c
if(!f){i.a=8
i.c=r}else{i.a=i.a&1|16
i.c=r}g.a=i
f=i}},
kb(a,b){if(t.Q.b(a))return b.aU(a)
if(t.v.b(a))return a
throw A.a(A.fc(a,"onError",u.c))},
k8(){var s,r
for(s=$.aQ;s!=null;s=$.aQ){$.bF=null
r=s.b
$.aQ=r
if(r==null)$.bE=null
s.a.$0()}},
kh(){$.fB=!0
try{A.k8()}finally{$.bF=null
$.fB=!1
if($.aQ!=null)$.fQ().$1(A.hM())}},
hK(a){var s=new A.cr(a),r=$.bE
if(r==null){$.aQ=$.bE=s
if(!$.fB)$.fQ().$1(A.hM())}else $.bE=r.b=s},
ke(a){var s,r,q,p=$.aQ
if(p==null){A.hK(a)
$.bF=$.bE
return}s=new A.cr(a)
r=$.bF
if(r==null){s.b=p
$.aQ=$.bF=s}else{q=r.b
s.b=q
$.bF=r.b=s
if(q==null)$.bE=s}},
kZ(a){A.fG(a,"stream",t.K)
return new A.cD()},
fC(a,b){A.ke(new A.eN(a,b))},
hI(a,b,c,d){var s,r=$.x
if(r===c)return d.$0()
$.x=c
s=r
try{r=d.$0()
return r}finally{$.x=s}},
kd(a,b,c,d,e){var s,r=$.x
if(r===c)return d.$1(e)
$.x=c
s=r
try{r=d.$1(e)
return r}finally{$.x=s}},
kc(a,b,c,d,e,f){var s,r=$.x
if(r===c)return d.$2(e,f)
$.x=c
s=r
try{r=d.$2(e,f)
return r}finally{$.x=s}},
cJ(a,b,c,d){if(B.h!==c){d=c.bs(d)
d=d}A.hK(d)},
e1:function e1(a){this.a=a},
e0:function e0(a,b,c){this.a=a
this.b=b
this.c=c},
e2:function e2(a){this.a=a},
e3:function e3(a){this.a=a},
ep:function ep(){},
eq:function eq(a,b){this.a=a
this.b=b},
cq:function cq(a,b){this.a=a
this.b=!1
this.$ti=b},
eF:function eF(a){this.a=a},
eG:function eG(a){this.a=a},
eO:function eO(a){this.a=a},
by:function by(a){var _=this
_.a=a
_.e=_.d=_.c=_.b=null},
aP:function aP(a,b){this.a=a
this.$ti=b},
S:function S(a,b){this.a=a
this.b=b},
cs:function cs(){},
bm:function bm(a,b){this.a=a
this.$ti=b},
aN:function aN(a,b,c,d,e){var _=this
_.a=null
_.b=a
_.c=b
_.d=c
_.e=d
_.$ti=e},
F:function F(a,b){var _=this
_.a=0
_.b=a
_.c=null
_.$ti=b},
e7:function e7(a,b){this.a=a
this.b=b},
eb:function eb(a,b){this.a=a
this.b=b},
ea:function ea(a,b){this.a=a
this.b=b},
e9:function e9(a,b){this.a=a
this.b=b},
e8:function e8(a,b){this.a=a
this.b=b},
ee:function ee(a,b,c){this.a=a
this.b=b
this.c=c},
ef:function ef(a,b){this.a=a
this.b=b},
eg:function eg(a){this.a=a},
ed:function ed(a,b){this.a=a
this.b=b},
ec:function ec(a,b){this.a=a
this.b=b},
cr:function cr(a){this.a=a
this.b=null},
cD:function cD(){},
eC:function eC(){},
en:function en(){},
eo:function eo(a,b){this.a=a
this.b=b},
eN:function eN(a,b){this.a=a
this.b=b},
iK(a,b){return new A.a9(a.i("@<0>").C(b).i("a9<1,2>"))},
m(a,b,c){return A.kw(a,new A.a9(b.i("@<0>").C(c).i("a9<1,2>")))},
iL(a,b){return new A.a9(a.i("@<0>").C(b).i("a9<1,2>"))},
iM(a){return new A.bo(a.i("bo<0>"))},
fx(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
ha(a,b,c){var s=A.iK(b,c)
s.N(0,a)
return s},
iN(a,b){var s,r,q=A.iM(b)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.cK)(a),++r)q.bq(0,b.a(a[r]))
return q},
hb(a){var s,r
if(A.fM(a))return"{...}"
s=new A.bh("")
try{r={}
$.av.push(a)
s.a+="{"
r.a=!0
a.I(0,new A.dh(r,s))
s.a+="}"}finally{$.av.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
bo:function bo(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
el:function el(a){this.a=a
this.b=null},
cx:function cx(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
v:function v(){},
I:function I(){},
dh:function dh(a,b){this.a=a
this.b=b},
aL:function aL(){},
bw:function bw(){},
k9(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.a_(r)
q=String(s)
throw A.a(new A.d8(q))}q=A.eM(p)
return q},
eM(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.cv(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.eM(a[s])
return a},
h8(a,b,c){return new A.b7(a,b)},
jK(a){return a.k()},
ja(a,b){return new A.ei(a,[],A.kt())},
jb(a,b,c){var s,r=new A.bh(""),q=A.ja(r,b)
q.a_(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
cv:function cv(a,b){this.a=a
this.b=b
this.c=null},
cw:function cw(a){this.a=a},
bN:function bN(){},
bP:function bP(){},
b7:function b7(a,b){this.a=a
this.b=b},
bY:function bY(a,b){this.a=a
this.b=b},
dd:function dd(){},
df:function df(a){this.b=a},
de:function de(a){this.a=a},
ej:function ej(){},
ek:function ek(a,b){this.a=a
this.b=b},
ei:function ei(a,b,c){this.c=a
this.a=b
this.b=c},
ix(a,b){a=A.z(a,new Error())
a.stack=b.j(0)
throw a},
a4(a,b,c,d){var s,r=c?J.h7(a,d):J.iF(a,d)
if(a!==0&&b!=null)for(s=0;s<r.length;++s)r[s]=b
return r},
fl(a,b,c){var s,r=A.k([],c.i("q<0>"))
for(s=J.bH(a);s.l();)r.push(s.gp())
r.$flags=1
return r},
W(a,b){var s,r
if(Array.isArray(a))return A.k(a.slice(0),b.i("q<0>"))
s=A.k([],b.i("q<0>"))
for(r=J.bH(a);r.l();)s.push(r.gp())
return s},
fm(a,b,c){var s,r=J.h7(a,c)
for(s=0;s<a;++s)r[s]=b.$1(s)
return r},
ar(a,b){var s=A.fl(a,!1,b)
s.$flags=3
return s},
hj(a,b,c){var s=J.bH(b)
if(!s.l())return a
if(c.length===0){do a+=A.u(s.gp())
while(s.l())}else{a+=A.u(s.gp())
while(s.l())a=a+c+A.u(s.gp())}return a},
iY(){return A.aT(new Error())},
h3(a){return new A.aD(a)},
iw(a,b){var s,r
for(s=0;s<3;++s){r=a[s]
if(r.b===b)return r}throw A.a(A.fc(b,"name","No enum value with that name"))},
bR(a){if(typeof a=="number"||A.at(a)||a==null)return J.bI(a)
if(typeof a=="string")return JSON.stringify(a)
return A.hh(a)},
iy(a,b){A.fG(a,"error",t.K)
A.fG(b,"stackTrace",t.l)
A.ix(a,b)},
bK(a){return new A.bJ(a)},
aW(a,b){return new A.a7(!1,null,b,a)},
fc(a,b,c){return new A.a7(!0,a,b,c)},
aK(a,b,c,d,e){return new A.cg(b,c,!0,a,d,"Invalid value")},
iW(a,b,c){if(0>a||a>c)throw A.a(A.aK(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.a(A.aK(b,a,c,"end",null))
return b}return c},
fr(a,b){if(a<0)throw A.a(A.aK(a,0,null,b,null))
return a},
h6(a,b,c,d){return new A.bS(b,!0,a,d,"Index out of range")},
cl(a){return new A.bk(a)},
hl(a){return new A.cj(a)},
fu(a){return new A.bg(a)},
a2(a){return new A.bO(a)},
iE(a,b,c){var s,r
if(A.fM(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.k([],t.s)
$.av.push(a)
try{A.k5(a,s)}finally{$.av.pop()}r=A.hj(b,s,", ")+c
return r.charCodeAt(0)==0?r:r},
fi(a,b,c){var s,r
if(A.fM(a))return b+"..."+c
s=new A.bh(b)
$.av.push(a)
try{r=s
r.a=A.hj(r.a,a,", ")}finally{$.av.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
k5(a,b){var s,r,q,p,o,n,m,l=a.gn(a),k=0,j=0
for(;;){if(!(k<80||j<3))break
if(!l.l())return
s=A.u(l.gp())
b.push(s)
k+=s.length+2;++j}if(!l.l()){if(j<=5)return
r=b.pop()
q=b.pop()}else{p=l.gp();++j
if(!l.l()){if(j<=4){b.push(A.u(p))
return}r=A.u(p)
q=b.pop()
k+=r.length+2}else{o=l.gp();++j
for(;l.l();p=o,o=n){n=l.gp();++j
if(j>100){for(;;){if(!(k>75&&j>3))break
k-=b.pop().length+2;--j}b.push("...")
return}}q=A.u(p)
r=A.u(o)
k+=r.length+q.length+4}}if(j>b.length+2){k+=5
m="..."}else m=null
for(;;){if(!(k>80&&b.length>3))break
k-=b.pop().length+2
if(m==null){k+=5
m="..."}}if(m!=null)b.push(m)
b.push(q)
b.push(r)},
fn(a,b,c,d){var s
if(B.m===c){s=B.c.gq(a)
b=J.a1(b)
return A.dw(A.ab(A.ab($.cL(),s),b))}if(B.m===d){s=B.c.gq(a)
b=J.a1(b)
c=J.a1(c)
return A.dw(A.ab(A.ab(A.ab($.cL(),s),b),c))}s=B.c.gq(a)
b=J.a1(b)
c=J.a1(c)
d=J.a1(d)
d=A.dw(A.ab(A.ab(A.ab(A.ab($.cL(),s),b),c),d))
return d},
iO(a){var s,r,q=$.cL()
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.cK)(a),++r)q=A.ab(q,J.a1(a[r]))
return A.dw(q)},
aD:function aD(a){this.a=a},
e5:function e5(){},
t:function t(){},
bJ:function bJ(a){this.a=a},
ac:function ac(){},
a7:function a7(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cg:function cg(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bS:function bS(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
bk:function bk(a){this.a=a},
cj:function cj(a){this.a=a},
bg:function bg(a){this.a=a},
bO:function bO(a){this.a=a},
c9:function c9(){},
bf:function bf(){},
e6:function e6(a){this.a=a},
d8:function d8(a){this.a=a},
G:function G(){},
ai:function ai(a,b,c){this.a=a
this.b=b
this.$ti=c},
J:function J(){},
h:function h(){},
cE:function cE(){},
dv:function dv(){this.b=this.a=0},
bh:function bh(a){this.a=a},
da:function da(a,b){this.a=a
this.b=b},
d1:function d1(a){this.b=a},
cT:function cT(a){this.a=a},
fZ(a,b,c,d,e,f,g){return new A.cR(A.l(d,"n2A",!0),A.l(e,"n2B",!0),A.l(a,"heA",!0),A.l(b,"heB",!0),new A.dy(A.l(f,"nitrogenHalfTimesMin",!0),A.l(c,"heliumHalfTimesMin",!0)))},
cS(){var s=t.n,r=A.k([5,8,12.5,18.5,27,38.3,54.3,77,109,146,187,239,305,390,498,635],s),q=A.k([1.88,3.02,4.72,6.99,10.21,14.48,20.53,29.11,41.2,55.19,70.69,90.34,115.29,147.42,188.24,240.03],s),p=A.k([1.1696,1,0.8618,0.7562,0.6667,0.56,0.4947,0.45,0.4187,0.3798,0.3497,0.3223,0.285,0.2737,0.2523,0.2327],s),o=A.k([0.5578,0.6514,0.7222,0.7825,0.8126,0.8434,0.8693,0.891,0.9092,0.9222,0.9319,0.9403,0.9477,0.9544,0.9602,0.9653],s)
return A.fZ(A.k([1.6189,1.383,1.1919,1.0458,0.922,0.8205,0.7305,0.6502,0.595,0.5545,0.5333,0.5189,0.5181,0.5176,0.5172,0.5119],s),A.k([0.477,0.5747,0.6527,0.7223,0.7582,0.7957,0.8279,0.8553,0.8757,0.8903,0.8997,0.9073,0.9122,0.9171,0.9217,0.9267],s),q,p,o,r,"zh-l16b-1b-v1")},
h_(){var s=t.n,r=A.k([5,8,12.5,18.5,27,38.3,54.3,77,109,146,187,239,305,390,498,635],s),q=A.k([1.88,3.02,4.72,6.99,10.21,14.48,20.53,29.11,41.2,55.19,70.69,90.34,115.29,147.42,188.24,240.03],s),p=A.k([1.1696,1,0.8618,0.7562,0.62,0.5043,0.441,0.4,0.375,0.35,0.3295,0.3065,0.2835,0.261,0.248,0.2327],s),o=A.k([0.5578,0.6514,0.7222,0.7825,0.8126,0.8434,0.8693,0.891,0.9092,0.9222,0.9319,0.9403,0.9477,0.9544,0.9602,0.9653],s)
return A.fZ(A.k([1.6189,1.383,1.1919,1.0458,0.922,0.8205,0.7305,0.6502,0.595,0.5545,0.5333,0.5189,0.5181,0.5176,0.5172,0.5119],s),A.k([0.477,0.5747,0.6527,0.7223,0.7582,0.7957,0.8279,0.8553,0.8757,0.8903,0.8997,0.9073,0.9122,0.9171,0.9217,0.9267],s),q,p,o,r,"zh-l16c-1b-v1")},
cR:function cR(a,b,c,d,e){var _=this
_.b=a
_.c=b
_.d=c
_.e=d
_.f=e},
ik(a,b,c,d,e,f,g){var s=new A.cM(c,a,b,d,f,g,e)
s.b1(a,b,c,d,e,f,g)
return s},
cM:function cM(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
U:function U(a,b,c){this.a=a
this.b=b
this.c=c},
fg(a,b){A.c(b,"oxygen",!0)
A.c(a,"helium",!0)
if(b+a>1)A.j(B.ad)
return new A.d9(b,a)},
h5(a){var s=A.y(a.h(0,"oxygen"),"oxygen")
return A.fg(A.y(a.h(0,"helium"),"helium"),s)},
io(a,b){var s
A.c(b,"setpointBar",!0)
if(b!==0){s=a.b
s=1-(a.a+s)+s===0}else s=!0
if(s)A.j(B.r)
return new A.a8(a,B.f,b)},
fY(a){var s="setpointBar",r=A.h5(A.M(a.h(0,"gas"),"gas"))
if(A.fI(a.h(0,"mode"),B.aP,"mode")===B.e){if(a.h(0,s)!=null)A.A("OC setpointBar")
return new A.a8(r,B.e,null)}return A.io(r,A.y(a.h(0,s),s))},
d9:function d9(a,b){this.a=a
this.b=b},
aY:function aY(a,b){this.a=a
this.b=b},
a8:function a8(a,b,c){this.a=a
this.b=b
this.c=c},
fS(a,b,c,d,e){var s=new A.bL(a,d,c,b,A.ar(e,t.J))
s.b2(a,b,c,d,e)
return s},
fT(a){var s="sourceDiveId",r="runtimeMin",q="initialOcGas",p="switches",o=A.bG(a.h(0,"id"),"id"),n=A.bG(a.h(0,s),s),m=A.y(a.h(0,r),r),l=A.h5(A.M(a.h(0,q),q)),k=a.h(0,p)
if(!t.j.b(k))A.A(p)
return A.fS(o,l,m,n,J.aA(k,new A.cO(),t.J))},
bL:function bL(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
cP:function cP(){},
cQ:function cQ(){},
cO:function cO(){},
ip(a8){var s,r,q,p,o,n,m,l,k,j,i,h,g,f="altitude",e="seaLevelBar",d="acclimatized",c="diveAltitudeMetres",b="initialAltitudeMetres",a="travelMin",a0="stepMetres",a1="lastStopMetres",a2="includeDescentInLevelTime",a3="vpmConservatism",a4=new A.d_(a8),a5=A.j3(A.M(a8.h(0,"vpm"),"vpm")),a6=A.M(a8.h(0,f),f),a7=a6.h(0,"enabled")
if(!A.at(a7))A.A("enabled")
s=A.y(a6.h(0,e),e)
r=a6.h(0,d)
if(!A.at(r))A.A(d)
a6=A.ik(r,A.y(a6.h(0,c),c),a7,A.y(a6.h(0,b),b),s,A.y(a6.h(0,a),a),A.y(a6.h(0,"waitMin"),"waitMin"))
a7=A.fI(a8.h(0,"model"),B.aQ,"model")
s=a4.$1("surfaceBar")
r=a4.$1("waterVapourBar")
r=A.hf(a4.$1("barPerMetre"),s,r)
s=a4.$1(a0)
q=a4.$1(a1)
p=new A.du(s,q)
A.c(s,a0,!0)
A.c(q,a1,!0)
if(s===0||q<s)A.j(B.aC)
s=a4.$1("gfLow")
q=a4.$1("gfHigh")
o=new A.da(s,q)
A.c(s,"GF low",!1)
A.c(q,"GF high",!1)
if(s<=0||q<s||q>1)A.j(B.as)
s=a4.$1("descentMetresPerMin")
q=a4.$1("ascentMetresPerMin")
n=a4.$1("minimumStopMin")
m=a8.h(0,a2)
if(!A.at(m))A.A(a2)
l=a4.$1("lowSetpointBar")
k=a8.h(0,a3)
if(!A.cI(k))A.A(a3)
j=a4.$1("bottomRmvLitresPerMin")
i=a4.$1("decoRmvLitresPerMin")
h=a4.$1("bottomOxygenLitresPerMin")
a4=a4.$1("decoOxygenLitresPerMin")
g=new A.cZ(a7,a5,a6,r,p,o,s,q,n,m,l,k,j,i,h,a4)
g.b4(a6,q,h,j,a4,i,s,o,m,l,n,a7,r,p,a5,k)
return g},
h9(a,b,c){A.c(b,"depthMetres",!0)
A.c(c,"durationMin",!0)
return new A.a3(b,c,a)},
h4(a){var s,r="depthMetres",q="breathing",p="minimumStopMin",o=A.y(a.h(0,r),r),n=A.fY(A.M(a.h(0,q),q)),m=a.h(0,"lost")
if(!A.at(m))A.A("lost")
s=a.h(0,p)==null?null:A.y(a.h(0,p),p)
A.c(o,"switch depth",!0)
if(s!=null){A.c(s,"gas minimumStopMin",!0)
if(s===0)A.j(B.al)}return new A.V(o,n,m,s)},
h1(a,b,c,d,e,f){var s=A.ar(c,t.L),r=A.ar(f,t.J)
if(a.length===0||s.length===0)A.j(B.F)
A.c(e,"surfaceIntervalMin",!0)
return new A.bQ(a,s,r,d,e,b)},
h2(a){var s,r,q,p,o,n="switches",m="settings",l="surfaceIntervalMin",k="initialState",j=A.bG(a.h(0,"id"),"id"),i=a.h(0,"levels"),h=t.j
if(!h.b(i))A.A("levels")
i=J.aA(i,new A.d4(),t.L)
s=a.h(0,n)
if(!h.b(s))A.A(n)
h=J.aA(s,new A.d5(),t.J)
s=A.ip(A.M(a.h(0,m),m))
r=A.y(a.h(0,l),l)
if(a.h(0,k)==null)q=null
else{q=A.M(a.h(0,k),k)
p=A.dB(A.M(q.h(0,"tissues"),"tissues"))
o=A.iR(A.M(q.h(0,"oxygen"),"oxygen"))
q=new A.U(p,o,q.h(0,"vpm")==null?null:A.j4(A.M(q.h(0,"vpm"),"vpm")))}return A.h1(j,q,i,s,r,h)},
aC:function aC(a,b){this.a=a
this.b=b},
cZ:function cZ(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p},
d_:function d_(a){this.a=a},
a3:function a3(a,b,c){this.a=a
this.b=b
this.c=c},
V:function V(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bQ:function bQ(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
d6:function d6(){},
d7:function d7(){},
d4:function d4(){},
d5:function d5(){},
ft(a,b,c,d){A.c(d,"segment startMin",!0)
A.c(d+c.c,"segment endMin",!0)
return new A.a5(c,b,d,a)},
ff(a,b,c,d,e,f,g,h){var s=new A.cX(c,f,e,g,A.ar(h,t.E),d,a,b)
s.b3(a,b,c,d,e,f,g,h)
return s},
aj:function aj(a,b){this.a=a
this.b=b},
a5:function a5(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cX:function cX(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
cY:function cY(){},
j2(a,b,c,d,e,f,g,h,i,j){var s=new A.dO(j,d,b,i,h,e,c,g,f,a)
s.b7(a,b,c,d,e,f,g,h,i,j)
return s},
j3(a){var s,r="criticalVolumeEnabled",q=new A.dP(a),p=A.bG(a.h(0,"version"),"version"),o=q.$1("nitrogenRadiusMetres"),n=q.$1("heliumRadiusMetres"),m=q.$1("surfaceTension"),l=q.$1("skinCompression"),k=q.$1("onsetImpermeabilityBar"),j=q.$1("lambdaPascalMinutes"),i=q.$1("regenerationMin")
q=q.$1("otherGasesBar")
s=a.h(0,r)
if(!A.at(s))A.A(r)
return A.j2(s,n,j,o,k,q,i,l,m,p)},
dO:function dO(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
dP:function dP(a){this.a=a},
fv(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6){var s=new A.dV(a4,A.l(r,"initialRadiusNitrogenMetres",!0),A.l(q,"initialRadiusHeliumMetres",!0),A.l(d,"adjustedInitialRadiusNitrogenMetres",!0),A.l(c,"adjustedInitialRadiusHeliumMetres",!0),A.l(a2,"maxCrushingPressureNitrogenBar",!1),A.l(a1,"maxCrushingPressureHeliumBar",!1),A.l(a8,"regeneratedRadiusNitrogenMetres",!0),A.l(a7,"regeneratedRadiusHeliumMetres",!0),A.l(b,"adjustedCrushingPressureNitrogenBar",!1),A.l(a,"adjustedCrushingPressureHeliumBar",!1),A.l(p,"initialAllowableGradientNitrogenBar",!1),A.l(o,"initialAllowableGradientHeliumBar",!1),A.l(f,"allowableGradientNitrogenBar",!1),A.l(e,"allowableGradientHeliumBar",!1),A.l(j,"boyleGradientNitrogenBar",!1),A.l(i,"boyleGradientHeliumBar",!1),A.l(a0,"maxActualGradientBar",!1),A.l(b3,"surfacePhaseVolumeMin",!1),A.l(b5,"totalPhaseVolumeMin",!1),A.l(a6,"previousPhaseVolumeMin",!1),A.l(g,"ambientOnsetBar",!1),A.l(b4,"tensionOnsetBar",!1),m,h,b1,b2,b6,a5,a3,n,a9,l,b0,k)
s.b8(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6)
return s},
hm(a,b,c,d){var s,r,q,p,o
if(a<0||a>=5)A.j(B.a8)
s=B.aS[a]
r=t.i
q=A.a4(16,b.b*s,!1,r)
p=A.a4(16,b.c*s,!1,r)
o=A.a4(16,0,!1,r)
return A.fv(o,o,p,q,o,o,o,d,o,o,0,0,d,0,o,o,p,q,o,o,o,0,b.a,b.x,o,p,q,0,0,d,c.a,o,o,o,c.b)},
j4(c2){var s,r,q,p,o,n,m,l,k,j,i,h="modelVersion",g="ascentStartTissues",f="segmentStartTissues",e="decoStartTissues",d="savedSegmentCount",c="criticalVolumeIterations",b=new A.dX(c2),a=new A.dW(c2),a0=A.bG(c2.h(0,h),h),a1=b.$1("initialRadiusNitrogenMetres"),a2=b.$1("initialRadiusHeliumMetres"),a3=b.$1("adjustedInitialRadiusNitrogenMetres"),a4=b.$1("adjustedInitialRadiusHeliumMetres"),a5=b.$1("maxCrushingPressureNitrogenBar"),a6=b.$1("maxCrushingPressureHeliumBar"),a7=b.$1("regeneratedRadiusNitrogenMetres"),a8=b.$1("regeneratedRadiusHeliumMetres"),a9=b.$1("adjustedCrushingPressureNitrogenBar"),b0=b.$1("adjustedCrushingPressureHeliumBar"),b1=b.$1("initialAllowableGradientNitrogenBar"),b2=b.$1("initialAllowableGradientHeliumBar"),b3=b.$1("allowableGradientNitrogenBar"),b4=b.$1("allowableGradientHeliumBar"),b5=b.$1("boyleGradientNitrogenBar"),b6=b.$1("boyleGradientHeliumBar"),b7=b.$1("maxActualGradientBar"),b8=b.$1("surfacePhaseVolumeMin"),b9=b.$1("totalPhaseVolumeMin"),c0=b.$1("previousPhaseVolumeMin"),c1=b.$1("ambientOnsetBar")
b=b.$1("tensionOnsetBar")
s=A.dB(A.M(c2.h(0,g),g))
r=A.dB(A.M(c2.h(0,f),f))
q=A.dB(A.M(c2.h(0,e),e))
p=a.$1("surfaceBar")
o=a.$1("vapourBar")
n=a.$1("otherGasesBar")
m=a.$1("maximumFirstStopMetres")
l=a.$1("decoZoneStartMin")
k=a.$1("savedRuntimeMin")
a=a.$1("decoPhaseVolumeMin")
j=c2.h(0,d)
if(!A.cI(j))A.A(d)
i=c2.h(0,c)
if(!A.cI(i))A.A(c)
return A.fv(b0,a9,a4,a3,b4,b3,c1,s,b6,b5,i,a,q,l,b2,b1,a2,a1,b7,a6,a5,m,a0,n,c0,a8,a7,k,j,r,p,b8,b,b9,o)},
dV:function dV(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s
_.cy=a0
_.db=a1
_.dx=a2
_.dy=a3
_.fr=a4
_.fx=a5
_.fy=a6
_.go=a7
_.id=a8
_.k1=a9
_.k2=b0
_.k3=b1
_.k4=b2
_.ok=b3
_.p1=b4
_.p2=b5},
dX:function dX(a){this.a=a},
dY:function dY(a){this.a=a},
dW:function dW(a){this.a=a},
o(a,b,c){return new A.e(a,b,c)},
T:function T(a,b){this.a=a
this.b=b},
e:function e(a,b,c){this.a=a
this.b=b
this.c=c},
fe(a,b){var s,r=new A.dv()
$.fP()
s=$.fq.$0()
r.a=s
r.b=null
if(b<=0||a.a<0)A.j(B.aG)
return new A.cU(b,a,r)},
f9(a,b,c,d,e,f){var s,r,q,p,o,n,m,l,k,j,i,h=!0
if(isFinite(c))if(isFinite(f))if(!(c>=f))if(isFinite(e))if(!(e<=0))if(isFinite(d))h=d<=0
if(h)throw A.a(B.a2)
s=a.e
r=new A.fa(a,b,s)
q=new A.fb()
p=r.$1(c)
o=r.$1(f)
if(Math.abs(p)<=e)return new A.bd(c)
if(Math.abs(o)<=e)return new A.bd(f)
if(!q.$2(p,o))throw A.a(B.ax)
for(n=f,m=c,l=0;l<256;++l){k=n-m
j=isFinite(k)?m+k/2:m/2+n/2
i=r.$1(j)
if(Math.abs(i)<=e)return new A.bd(j)
if(j===m||j===n||Math.abs(k)<=d)break
if(q.$2(p,i))n=j
else{p=i
m=j}}throw A.a(A.o(B.j,"No root satisfying the residual tolerance within search limits.",a.e-s))},
cU:function cU(a,b,c){var _=this
_.a=a
_.b=b
_.d=c
_.e=0},
bd:function bd(a){this.a=a},
fa:function fa(a,b,c){this.a=a
this.b=b
this.c=c},
fb:function fb(){},
dk(a,b){A.c(a,"cnsFraction",!0)
A.c(b,"otu",!0)
return new A.ca(a,null,b)},
dl(a,b){A.c(a,"otu",!0)
if(b.a!==B.n)A.j(B.aq)
return new A.ca(null,b,a)},
iR(a){var s,r,q="cnsFraction",p="cnsUnavailableReason",o="iterations",n=A.y(a.h(0,"otu"),"otu")
if(a.h(0,q)==null){s=A.M(a.h(0,p),p)
r=s.h(0,o)
if(!A.cI(r))A.A(o)
if(r<0)A.A(o)
return A.dl(n,new A.e(A.fI(s.h(0,"code"),B.aO,"code"),A.bG(s.h(0,"message"),"message"),r))}if(a.h(0,p)!=null)A.A(p)
return A.dk(A.y(a.h(0,q),q),n)},
iQ(a,b,c,d){var s,r,q,p,o,n,m,l,k,j,i,h,g
A.c(b,"durationMin",!0)
s=A.hc(d)
r=A.hc(c)
if(b===0)return a
if(s===r){if(s<=0.5)return a
q=B.b.bT(B.I,new A.dj(s)).a
p=b/(q[3]*s+q[1])}else{o=Math.min(s,r)
n=Math.max(s,r)
if(n<=0.5)return a
m=(n-o)/b
for(p=0,l=0;l<7;++l){q=B.I[l].a
k=Math.max(o,q[2])
j=Math.min(n,q[0])
if(j<=k)continue
i=q[3]
p+=A.hd(i*(j-k)/(i*k+q[1]))/(q[3]*m)}}h=a.c+A.he(s,r,b)
g=a.b
if(g!=null)return A.dl(h,g)
q=a.a
q.toString
return A.dk(q+p,h)},
he(a,b,c){var s,r,q,p,o,n,m="OTU dose"
if(c===0)return 0
s=Math.min(a,b)
r=Math.max(a,b)
if(r<=0.5)return 0
if(a===b){q=c*Math.pow(2*(a-0.5),0.8333333333333334)
A.c(q,m,!0)
return q}p=Math.max(s,0.5)
if(p===0.5)o=Math.pow(2*(r-0.5),1.8333333333333333)
else{n=p-0.5
o=Math.pow(2*n,1.8333333333333333)*A.iP(1.8333333333333333*A.hd((r-p)/n))}q=0.2727272727272727*o/((r-s)/c)
A.c(q,m,!0)
return q},
aI(a,b,c,d){var s,r,q
if(b===0)return a
try{r=A.iQ(a,b,c,d)
return r}catch(q){r=A.a_(q)
if(r instanceof A.e){s=r
if(s.a!==B.n)throw q
r=a.b
if(r==null)r=s
A.c(d,"startOxygenBar",!0)
A.c(c,"endOxygenBar",!0)
A.c(b,"durationMin",!0)
return A.dl(a.c+A.he(A.dG(d,0.9869232667160128),A.dG(c,0.9869232667160128),b),r)}else throw q}},
fo(a,b,c){var s,r,q,p=c.D(b.a),o=c.D(b.b),n=b.d
if(n.b===B.e){s=n.a.a
return A.aI(a,b.c,o*s,p*s)}s=n.c
s.toString
if(p!==o){r=(s-p)/(o-p)
if(r>0&&r<1){q=b.c
return A.aI(A.aI(a,q*r,s,Math.min(p,s)),q*(1-r),Math.min(o,s),s)}}q=Math.min(p,s)
return A.aI(a,b.c,Math.min(o,s),q)},
fp(a,b){var s,r
A.c(b,"surface interval",!0)
if(b===0)return a
s=a.b
if(s!=null)return A.dl(a.c,s)
r=a.a
r.toString
return A.dk(r*Math.exp(-0.6931471805599453*b/90),a.c)},
hc(a){A.c(a,"oxygenBar",!0)
if(a>1.6212)throw A.a(B.ag)
return Math.min(1.6,A.dG(a,0.9869232667160128))},
hd(a){var s,r
if(Math.abs(a)>=0.0001)return Math.log(1+a)
s=a*a
r=s*a
return a*(1-a/2+s/3-r/4+r*a/5)},
iP(a){var s,r
if(Math.abs(a)>=0.0001)return Math.exp(a)-1
s=a*a
r=s*a
return a*(1+a/2+s/6+r/24+r*a/120)},
ca:function ca(a,b,c){this.a=a
this.b=b
this.c=c},
dj:function dj(a){this.a=a},
hZ(b2,b3,b4,b5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=b3.c,b1=!0
if(!(b0<=0)){s=b2.e
r=s.length===0
if(r)q=0
else{q=B.b.gA(s)
q=q.c+q.a.c}if(!(b0>q)){if(r)b1=0
else{b1=B.b.gA(s)
b1=b1.c+b1.a.c}if(b0===b1)b1=B.b.gA(s).a.b<=0||B.b.gA(s).a.d.b!==B.f
else b1=!1}}if(b1)throw A.a(B.a0)
p=A.k([],t.G)
o=b2.c
b1=b4.a
n=b1===B.H?A.h_().f:A.cS().f
for(s=b2.e,r=s.length,q=b2.d,b1=b1===B.d,m=b4.b,l=q.a,k=q.c,j=o,i=0,h=0,g=0,f=0,e=!1,d=0;d<r;++d){c=s[d]
b5.u();++b5.e
b=c.a
a=c.c
a0=b.c
a1=a+a0
if(a1>b0&&b.d.b!==B.f)throw A.a(B.an)
if(a>=b0)break
a2=Math.min(a0,b0-a)
a3=a1<=b0
i=b.b
if(!a3){a1=b.a
i=a1+(i-a1)*(a2/a0)}a0=b.a
a1=b.d
a4=new A.aJ(a0,i,a2,a1)
a4.al(a1,a2,i,a0)
j=a3?c.d:new A.U(n.B(a1,a2,i,j.a,q,a0),A.fo(j.b,a4,q),null)
a1=!a3
if(a1&&b1){a5=p.length===0?o:B.b.gA(p).d
a6=a5.c
a6.toString
if(i>a0)a7=new A.cn(m,n,b5).aK(a6,a5.a,q,a4)
else{a0=c.b
a8=a0===B.l
if(a8||a0===B.k){a7=c.d.c.bG(a6.CW,a5.a)
if(a8){if(isFinite(i))a0=i<0
else a0=!0
if(a0)A.j(A.o(B.a,u.m,0))
a9=l+i*k
if(!isFinite(a9))A.j(A.o(B.a,"ambientBar must be finite.",0))
a7=new A.cm(m,n,b5).aT(a7,j.a,a9)}}else a7=a6}j=new A.U(j.a,j.b,a7)}if(a3)a=c
else{a0=new A.a5(a4,c.b,a,j)
if(isFinite(a))a6=a<0
else a6=!0
if(a6)A.j(A.o(B.a,"segment startMin must be finite and nonnegative.",0))
a+=a2
if(isFinite(a))a=a<0
else a=!0
if(a)A.j(A.o(B.a,"segment endMin must be finite and nonnegative.",0))
a=a0}p.push(a)
a=c.b
a0=a===B.k
if(a0){if(!e)h=i
e=!0}if(a===B.l||a0){g+=a2
if(e)f+=a2}if(a1)break}if(i<=0)throw A.a(B.a3)
if(b1)h=B.b.bW(p,0,new A.f3())
b1=b3.a
return new A.cN(A.h1(b1,null,A.k([A.h9(new A.a8(b3.d,B.e,null),i,0)],t._),b4,0,b3.e),A.ff(g,f,b1,h,o,b2.b,q,p))},
cN:function cN(a,b){this.a=a
this.b=b},
f3:function f3(){},
cH(b3,b4,b5,b6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=null,b0={},b1=b3.d,b2=b1.a
if(b2===B.d)throw A.a(B.Y)
s=b2===B.G?A.cS():A.h_()
b2=b5==null
r=b2?A.i_(b1,b3.f):a9
q=b2?a9:b5.d
if(q==null)q=r.a
p=b2?a9:b5.c
if(p==null)p=A.i2(r.b,b3.e,s.f,b1.b,q)
o=b2?a9:b5.gO()
b0.a=(o==null?p:o).a
o=b2?a9:b5.gO()
b0.b=(o==null?p:o).b
n=b2?a9:B.b.gA(b5.e).a.b
b0.c=n==null?0:n
if(b2)m=a9
else{o=b5.e
if(o.length===0)o=0
else{o=B.b.gA(o)
o=o.c+o.a.c}m=o}b0.d=m==null?0:m
b0.e=b0.f=0
l=b2?a9:b5.f
b0.r=b0.w=l==null?0:l
o=b3.b
b0.x=B.b.gaN(o).c
k=A.k([],t.G)
j=b2?a9:b5.e
if(j!=null)B.b.N(k,j)
j=!b2
if(j){b0.f=b5.r
b0.e=b5.w}b0.y=null
i=new A.eH(b0,b4,s,q,k)
h=new A.eK()
g=new A.eL(b0,b3,h)
f=new A.eI(b0,new A.cT(s),b1,b1.f,q,b1.e,b4,new A.eJ(b0,b3,h),i,g,s)
if(j)g.$0()
b2=b2?o:B.J
o=b2.length
j=b1.r
e=b1.w
d=b1.y
b1=b1.z
c=b1<0
b=0
for(;b<o;++b){a=b2[b]
a0=a.a
a1=b0.c
if(a0<a1){f.$1(a0)
b0.x=a.c
a0=Math.ceil(b0.d)
a1=b0.d
i.$3(b0.c,a.b+(a0-a1),B.p)
continue}if(a0>a1){b0.w=0
b0.y=null
a2=a.c
if(a2.b===B.f){a3=a2.a
a4=new A.a8(a3,B.f,b1)
if(isFinite(b1))a5=c
else a5=!0
if(a5)A.j(A.o(B.a,u.o,0))
if(b1!==0){a5=a3.b
a5=1-(a3.a+a5)+a5===0
a3=a5}else a3=!0
if(a3)A.j(B.r)}else a4=a2
b0.x=a4
a6=A.i0(e,j,d,a.b,a2,a4,a1,a0)
for(a0=a6.length,a7=0;a7<a0;++a7){a8=a6[a7]
b0.x=a8.d
a1=a8.b
a3=a8.a!==a1?B.L:B.p
i.$3(a1,a8.c,a3)}}else{b0.x=a.c
i.$3(a1,a.b,B.p)}}if(!b6)f.$1(0)
b1=b0.r
return A.ff(b0.f,b0.e,b3.a,b1,p,"deco-core-calculation-v1-dev",q,k)},
hO(a,b,c){var s,r,q,p=a.a
if(b.b!==p||b.a===p)throw A.a(B.E)
s=A.cH(a,c,null,!0)
p=s.e
if(p.length===0)p=0
else{p=B.b.gA(p)
p=p.c+p.a.c}r=b.c<=p?s:A.cH(a,c,null,!1)
q=A.hZ(r,b,a.d,c)
return A.cH(q.a,c,q.b,!1)},
eH:function eH(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
eK:function eK(){},
eL:function eL(a,b,c){this.a=a
this.b=b
this.c=c},
eJ:function eJ(a,b,c){this.a=a
this.b=b
this.c=c},
eI:function eI(a,b,c,d,e,f,g,h,i,j,k){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k},
hP(a,b,c,d,e,f){return new A.aP(A.kr(a,b,c,d,e,f),t.h)},
kr(a,b,c,d,e,f){return function(){var s=a,r=b,q=c,p=d,o=e,n=f
var m=0,l=1,k=[],j,i,h,g,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1
return function $async$hP(d3,d4,d5){if(d4===1){k.push(d5)
m=l}for(;;)switch(m){case 0:d0=A.iN(n,A.R(n).c)
d1=A.W(d0,A.Y(d0).c)
d0=!0
a2=d1.length
if(a2!==0){d0=q.d
d0===$&&A.r()
a3=p.d
a3===$&&A.r()
a2=d0*a3*a2>1000
d0=a2}if(d0)throw A.a(B.a_)
d0=s==null
if(!d0&&s.b!==o.a)throw A.a(B.a5)
j=r
a2=o.d
a3=a2.a===B.d
a4=t.I
a5=o.c
a6=A.R(a5).i("bl<1>")
a7=o.e
a8=o.f
a9=t.L
b0=t.J
b1=o.b
b2=o.a
b3=b1.length-1
b4=a7<0
b5=0
case 2:b6=q.d
b6===$&&A.r()
if(!(b5<b6)){m=3
break}b7=0
case 4:b6=p.d
b6===$&&A.r()
if(!(b7<b6)){m=5
break}b6=d1.length,b8=0
case 6:if(!(b8<d1.length)){m=8
break}b9=d1[b8]
c0=j
c0.u();++c0.e
c1=q.aD(b5)
c2=p.aD(b7)
c3=B.b.gA(b1)
c0=A.R(b1)
c4=new A.bi(b1,0,b3,c0.i("bi<1>"))
c4.b6(b1,0,b3,c0.c)
c0=A.W(c4,a9)
if(isFinite(c1))c4=c1<0
else c4=!0
if(c4)A.j(A.o(B.a,u.m,0))
if(isFinite(c2))c4=c2<0
else c4=!0
if(c4)A.j(A.o(B.a,"durationMin must be finite and nonnegative.",0))
c0.push(new A.a3(c1,c2,c3.c))
c5=A.fl(c0,!1,a9)
c5.$flags=3
c0=c5
c5=A.fl(new A.bl(a5,new A.eP(b9),a6),!1,b0)
c5.$flags=3
if(b2.length===0||c0.length===0)A.j(B.F)
if(isFinite(a7))c4=b4
else c4=!0
if(c4)A.j(A.o(B.a,"surfaceIntervalMin must be finite and nonnegative.",0))
i=new A.bQ(b2,c0,c5,a2,a7,a8)
if(d0)c6=null
else{c0=s.a
c4=s.b
c7=s.c
c8=s.d
c6=A.fS(c0,c8,c7,c4,b9===B.v?s.e:A.k([],a4))}h=c6
g=null
a0=null
try{if(h!=null)g=a3?A.hR(i,h,j):A.hO(i,h,j)
else{if(a3){c0=i
c4=j
if(c0.d.a!==B.d)A.j(B.t)
c5=A.ev(c0,c4==null?A.fe(B.aH,1e5):c4).aF()}else c5=A.cH(i,j,null,!1)
g=c5}}catch(d2){c0=A.a_(d2)
if(c0 instanceof A.e){a1=c0
if(a1.a===B.C||a1.a===B.q)throw d2
a0=a1}else throw d2}j.af(!1)
m=9
return d3.b=new A.cf(c1,c2,b9,i,h,g,a0),1
case 9:case 7:d1.length===b6||(0,A.cK)(d1),++b8
m=6
break
case 8:++b7
m=4
break
case 5:++b5
m=2
break
case 3:return 0
case 1:return d3.c=k.at(-1),3}}}},
aa:function aa(a,b){this.a=a
this.b=b},
dr:function dr(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=$},
cf:function cf(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
eP:function eP(a){this.a=a},
hN(a,b){var s,r
A.c(a,"altitudeMetres",!0)
A.c(b,"seaLevelBar",!0)
if(a>11e3||b===0)throw A.a(B.ao)
s=a/1000
r=b*Math.exp(Math.log(288.15/(288.15-6.5*(s*6369/(s+6369))))*34.163194736310366/-6.5)
A.c(r,"barometric pressure",!0)
return r},
fF(a,b,c,d){var s,r=b*0.21,q=c*0.21,p=A.dG(0.5,1.01325)
if(Math.max(r,q)<=p)return A.fp(a,d)
if(Math.min(r,q)>p)return A.aI(a,d,q,r)
s=(p-r)/(q-r)
if(r>p)return A.fp(A.aI(a,d*s,p,r),d*(1-s))
return A.aI(A.fp(a,d*s),d*(1-s),q,p)},
i_(a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c="nitrogenBar",b="heliumBar",a={},a0=a3.c,a1=a0.a,a2=a3.d
if(a1)a2=A.hf(a2.c,A.hN(a0.c,a0.r),a2.b)
if(a4!=null)return new A.cc(a2,a4)
s=a3.b
r=A.cS().f
q=a1&&!a0.b?A.hN(a0.d,a0.r):a2.a
p=(q-a2.b)*0.79
o=t.i
n=A.a4(16,p,!1,o)
m=A.a4(16,0,!1,o)
n=A.l(n,c,!1)
m=A.l(m,b,!1)
l=new A.N(n,m)
a.a=l
k=A.dk(0,0)
j=a3.a===B.d?A.hm(a3.Q,s,a2,l):null
if(a1&&!a0.b){a1=a2.a
i=a0.e
h=(a1-q)/i*0.79
g=J.b0(16,o)
for(o=r.a,f=0;f<16;++f)g[f]=A.i3(i,n[f],h,p,0.6931471805599453/o[f])
a.a=new A.N(A.l(g,c,!1),A.l(m,b,!1))
k=A.fF(k,q,a1,i)
if(j!=null){p=new A.f4(a,s,a2,Math.exp(-a0.f/s.w))
e=p.$1(j.b)
d=p.$1(j.c)
j=j.bL(d,e,d,e,d,e)}p=a.a
o=a0.f
a.a=r.B(new A.a8(A.fg(0,0.21),B.e,null),o,0,p,a2,0)
k=A.fF(k,a1,a1,o)}if(j==null)j=null
else{a1=a.a
j=j.bH(a1,a1,a1)}return new A.cc(a2,new A.U(a.a,k,j))},
kx(a,b){var s=new A.eS(a,b),r=s.$3(a.b,a.Q,a.y)
return a.aJ(s.$3(a.c,a.as,a.z),r)},
i2(a,b,c,d,e){var s,r,q,p
A.c(b,"surface interval",!0)
if(b===0)return a
s=c.B(new A.a8(A.fg(0,0.21),B.e,null),b,0,a.a,e,0)
r=a.c
if(r!=null){q=new A.f6(Math.exp(-b/d.w))
p=q.$2(r.b,r.d)
r=r.aJ(q.$2(r.c,r.e),p)}q=e.a
return new A.U(s,A.fF(a.b,q,q,b),r)},
cc:function cc(a,b){this.a=a
this.b=b},
f4:function f4(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
f5:function f5(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
eS:function eS(a,b){this.a=a
this.b=b},
eT:function eT(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
f6:function f6(a){this.a=a},
hQ(a,b){if(a.d.a!==B.d)throw A.a(B.t)
return A.ev(a,b).aF()},
hR(a,b,c){var s,r,q,p=a.a
if(b.b!==p||b.a===p)throw A.a(B.E)
p=a.d
if(p.a!==B.d)throw A.a(B.t)
s=A.ev(a,c).bv(!0)
r=s.e
if(r.length===0)r=0
else{r=B.b.gA(r)
r=r.c+r.a.c}q=A.hZ(b.c<=r?s:A.hQ(a,c),b,p,c)
return A.ev(q.a,c).bu(q.b)},
ev(a,b){return new A.eu(a,b,A.cS().f,A.k([],t.G))},
hH(a){var s,r
A.c(a,"VPM stop alignment",!1)
s=Math.floor(a)
r=a-Math.floor(a)
if(r<0.5)return s
if(r>0.5)return s+1
return B.i.aZ(s,2)===0?s:s+1},
cF:function cF(a,b,c){this.a=a
this.b=b
this.d=c},
e_:function e_(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eu:function eu(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.y=_.x=_.w=_.r=_.f=_.e=_.d=$
_.z=d
_.ay=_.ax=_.at=_.as=_.Q=0},
ez:function ez(a){this.a=a},
eB:function eB(a,b){this.a=a
this.b=b},
eA:function eA(a,b,c){this.a=a
this.b=b
this.c=c},
ex:function ex(){},
ey:function ey(a,b,c){this.a=a
this.b=b
this.c=c},
ew:function ew(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dq(a,b,c,d){A.c(d,"startDepthMetres",!0)
A.c(c,"endDepthMetres",!0)
A.c(b,"durationMin",!0)
if(b===0&&d!==c)A.j(B.u)
return new A.aJ(d,c,b,a)},
i0(a,b,c,d,e,f,g,h){var s,r,q,p,o,n,m
for(s=A.m(["startDepthMetres",g,"targetDepthMetres",h,"levelDurationMin",d,"descentMetresPerMin",b,"ascentMetresPerMin",a],t.N,t.i),s=new A.C(s,s.$ti.i("C<1,2>")).gn(0);s.l();){r=s.d
q=r.b
p=r.a
if(isFinite(q))q=q<0
else q=!0
if(q)A.j(A.o(B.a,p+" must be finite and nonnegative.",0))}if(b===0||a===0)throw A.a(B.ab)
o=h>g
s=o?b:a
n=Math.abs(h-g)/s
m=d-(o&&c?n:0)
if(m<0)throw A.a(B.am)
s=[]
if(n>0)s.push(A.dq(f,n,h,g))
if(m>0)s.push(A.dq(e,m,h,h))
return A.ar(s,t.q)},
aJ:function aJ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
l(a,b,c){var s,r,q,p=A.ar(a,t.i),o=p.length
if(o!==16)throw A.a(A.o(B.a,b+" must contain exactly sixteen values.",0))
for(s=0;s<o;++s){r=p[s]
if(isFinite(r))q=r<0
else q=!0
if(q)A.j(A.o(B.a,b+" must be finite and nonnegative.",0))
if(c&&r===0)throw A.a(A.o(B.a,b+" must be positive.",0))}return p},
dB(a){var s,r,q="nitrogenBar",p="heliumBar",o=a.h(0,q),n=t.j
if(!n.b(o))A.A(q)
s=t.i
o=J.aA(o,new A.dC(),s)
r=a.h(0,p)
if(!n.b(r))A.A(p)
n=J.aA(r,new A.dD(),s)
return new A.N(A.l(o,q,!1),A.l(n,p,!1))},
fL(a,b,c){var s,r,q,p,o,n
A.c(a,"ambientBar",!0)
A.c(b,"vapourBar",!0)
s=a-b
if(s<0)throw A.a(B.X)
r=c.a
if(c.b===B.e){q=r.b
return new A.bv(s*q,s*(1-(r.a+q)))}q=c.c
q.toString
p=Math.max(0,s-q)
q=r.b
o=1-(r.a+q)
n=o+q
return new A.bv(p*q/n,p*o/n)},
i3(a,b,c,d,e){var s,r,q,p,o,n,m="tissue pressure"
A.c(b,"initial",!0)
A.c(d,"inspiredStart",!0)
A.c(c,"inspiredRate",!1)
A.c(a,"durationMin",!0)
A.c(e,"rateConstant",!0)
if(e===0||d+c*a<-1e-12)throw A.a(B.ae)
if(a===0)return b
if(c===0){s=d+(b-d)*Math.exp(-e*a)
A.c(s,m,!0)
return s}r=e*a
q=r<0.0001
if(q){p=r*r
o=r*(1-r/2+p/6-p*r/24)}else o=1-Math.exp(-r)
if(q){q=r*r
n=q*(0.5-r/6+q/24-q*r/120)}else n=r-o
s=b+(d-b)*o+c/e*n
A.c(s,m,!0)
return s},
N:function N(a,b){this.a=a
this.b=b},
dC:function dC(){},
dD:function dD(){},
dy:function dy(a,b){this.a=a
this.b=b},
dz:function dz(a,b,c){this.a=a
this.b=b
this.c=c},
dA:function dA(a){this.a=a},
c(a,b,c){var s
if(isFinite(a))s=c&&a<0
else s=!0
if(s){s=c?" and nonnegative":""
throw A.a(A.o(B.a,b+" must be finite"+s+".",0))}},
dG(a,b){var s
A.c(a,"value",!1)
s=a*b
A.c(s,"converted value",!1)
return s},
hf(a,b,c){A.c(b,"surfaceBar",!0)
A.c(c,"waterVapourBar",!0)
A.c(a,"barPerMetre",!0)
if(b<=c||a===0)A.j(B.a1)
return new A.dm(b,c,a)},
dm:function dm(a,b,c){this.a=a
this.b=b
this.c=c},
du:function du(a,b){this.a=a
this.b=b},
cm:function cm(a,b,c){this.a=a
this.b=b
this.c=c},
dH:function dH(a,b,c){this.a=a
this.b=b
this.c=c},
dJ:function dJ(a,b,c){this.a=a
this.b=b
this.c=c},
dI:function dI(a,b){this.a=a
this.b=b},
dL:function dL(a){this.a=a},
dK:function dK(a){this.a=a},
dM:function dM(a,b){this.a=a
this.b=b},
dN:function dN(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cn:function cn(a,b,c){this.a=a
this.b=b
this.c=c},
dQ:function dQ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dR:function dR(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
dS:function dS(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
dT:function dT(a,b){this.a=a
this.b=b},
dU:function dU(a,b){this.a=a
this.b=b},
kM(b0,b1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7=t.N,a8=t.X,a9=A.iL(a7,a8)
for(a0=["requestId","inputRevision","dependencyVersion","modelVersion","protocolVersion"],a1=0;a1<5;++a1){a2=a0[a1]
a9.M(0,a2,b0.h(0,a2))}s=new A.f7(b1,a9)
try{if(!J.a0(b0.h(0,"protocolVersion"),2)||!J.a0(b0.h(0,"modelVersion"),"deco-core-calculation-v1-dev"))throw A.a(B.T)
s.$1(A.m(["event","progress","stage","starting"],a7,a8))
a9=t.M
r=A.h2(a9.a(b0.h(0,"request")).ad(0,a7,a8))
q=b0.h(0,"bailout")
p=q==null?null:A.fT(a9.a(q).ad(0,a7,a8))
a9=A.cG(b0.h(0,"maxIterations"))
o=A.fe(A.h3(A.cG(b0.h(0,"numericalTimeLimitMicros"))),a9)
s.$1(A.m(["event","progress","stage","calculating"],a7,a8))
n=null
m=new A.cB(r.d.a,p)
l=null
k=!1
j=null
i=!1
h=null
g=!1
A:{f=null
if(k)a9=l
else{k=!0
a3=B.d===m.a
l=a3
a9=a3}if(a9){if(i)a9=j
else{i=!0
a4=m.b
j=a4
a9=a4}a9=a9!=null}else a9=!1
if(a9){if(i){a9=j
e=a9}else{i=!0
a4=m.b
j=a4
e=a4}f=e==null?t.A.a(e):e
n=A.hR(r,f,o)
break A}e=null
if(i)a9=j
else{i=!0
a4=m.b
j=a4
a9=a4}if(a9!=null){if(i){a9=j
f=a9}else{i=!0
a4=m.b
j=a4
f=a4}e=f==null?t.A.a(f):f
n=A.hO(r,e,o)
break A}if(k)a9=l
else{k=!0
a3=B.d===m.a
l=a3
a9=a3}if(a9)if(g)a9=h
else{g=!0
if(i)a9=j
else{i=!0
a4=m.b
j=a4
a9=a4}a5=a9==null
h=a5
a9=a5}else a9=!1
if(a9){n=A.hQ(r,o)
break A}if(g)a9=h
else{g=!0
if(i)a9=j
else{i=!0
a4=m.b
j=a4
a9=a4}a5=a9==null
h=a5
a9=a5}if(a9){n=A.cH(r,o,null,!1)
break A}}d=n
s.$1(A.m(["event","result","result",d.k()],a7,a8))}catch(a6){n=A.a_(a6)
if(n instanceof A.e){c=n
s.$1(A.m(["event","failure","kind","calculation","message",c.b,"calculationFailure",c.k()],a7,a8))}else if(n instanceof A.cp){b=n
b.toString
b.toString
s.$1(A.m(["event","failure","kind","protocol","message","Calculation worker version is incompatible."],a7,a8))}else{a=n
s.$1(A.m(["event","failure","kind","unexpected","message","Calculation failed: "+A.u(a)],a7,a8))}}},
dZ:function dZ(a,b){this.a=a
this.b=b},
cp:function cp(){},
cV:function cV(a,b,c){this.a=a
this.b=b
this.c=c},
cW:function cW(a){this.a=a},
f7:function f7(a,b){this.a=a
this.b=b},
f8(a,b,c,d,e,f,g,h){return A.kN(a,b,c,d,e,f,g,h)},
kN(a3,a4,a5,a6,a7,a8,a9,b0){var s=0,r=A.k7(t.o),q,p=2,o=[],n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
var $async$f8=A.km(function(b1,b2){if(b1===1){o.push(b2)
s=p}for(;;)switch(s){case 0:p=4
k=new A.by(A.hP(a3,A.fe(B.aI,5e6),a4,a5,a8,a9).a()),j=t.N,i=t.X
case 7:if(!k.l()){s=8
break}n=k.b
m=n.f
h=n.d
g=n.e
f=n.a
e=n.b
d=n.c
c=m
if(c==null)c=null
else{c=c.e
if(c.length===0)c=0
else{c=B.b.gA(c)
c=c.c+c.a.c}}b=m
b=b==null?null:b.r
a=m
a=a==null?null:a.w
a0=m
a0=a0==null?null:a0.f
a7.$1(A.m(["identity",a6,"cell",new A.ch(h,g,f,e,d,c,b,a,a0,n.r)],j,i))
s=9
return A.jE(b0.$0(),$async$f8)
case 9:if(!b2){s=1
break}s=7
break
case 8:a7.$1(A.m(["identity",a6,"done",!0],j,i))
p=2
s=6
break
case 4:p=3
a2=o.pop()
k=A.a_(a2)
if(k instanceof A.e){l=k
a7.$1(A.m(["identity",a6,"failure",l],t.N,t.X))}else throw a2
s=6
break
case 3:s=2
break
case 6:case 1:return A.jG(q,r)
case 2:return A.jF(o.at(-1),r)}})
return A.jH($async$f8,r)},
ch:function ch(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
fD(a){return v.G.self.postMessage(B.z.bP(a,null))},
hB(a){var s=A.eD(a.h(0,"first")),r=A.eD(a.h(0,"last")),q=A.eD(a.h(0,"step")),p=new A.dr(s,r,q)
p.b5(s,r,q)
return p},
kH(){var s,r,q={}
q.a=null
s=v.G.self
q=new A.f1(q)
if(typeof q=="function")A.j(A.aW("Attempting to rewrap a JS function.",null))
r=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.jJ,q)
r[$.fO()]=q
s.onmessage=r},
f1:function f1(a){this.a=a},
eZ:function eZ(){},
f_:function f_(){},
f0:function f0(a){this.a=a},
jJ(a,b,c){if(c>=1)return a.$1(b)
return a.$0()},
A(a){return A.j(A.o(B.a,"Invalid JSON field: "+a+".",0))},
M(a,b){if(!t.f.b(a))A.A(b)
return a},
y(a,b){if(typeof a!="number"||!isFinite(a))A.A(b)
return a},
bG(a,b){if(typeof a!="string"||a.length===0)A.A(b)
return a},
fI(a,b,c){var s,r,q
for(s=b.length,r=0;r<s;++r){q=b[r]
if(q.b===a)return q}return A.A(c)}},B={}
var w=[A,J,B]
var $={}
A.fj.prototype={}
J.bT.prototype={
G(a,b){return a===b},
gq(a){return A.cd(a)},
j(a){return"Instance of '"+A.ce(a)+"'"},
gt(a){return A.aw(A.fA(this))}}
J.bV.prototype={
j(a){return String(a)},
gq(a){return a?519018:218159},
gt(a){return A.aw(t.y)},
$ip:1,
$iL:1}
J.b2.prototype={
G(a,b){return null==b},
j(a){return"null"},
gq(a){return 0},
$ip:1}
J.b5.prototype={$iw:1}
J.ah.prototype={
gq(a){return 0},
j(a){return String(a)}}
J.cb.prototype={}
J.bj.prototype={}
J.af.prototype={
j(a){var s=a[$.fO()]
if(s==null)return this.b0(a)
return"JavaScript function for "+J.bI(s)}}
J.b4.prototype={
gq(a){return 0},
j(a){return String(a)}}
J.b6.prototype={
gq(a){return 0},
j(a){return String(a)}}
J.q.prototype={
N(a,b){a.$flags&1&&A.kQ(a,"addAll",2)
this.bb(a,b)
return},
bb(a,b){var s,r=b.length
if(r===0)return
if(a===b)throw A.a(A.a2(a))
for(s=0;s<r;++s)a.push(b[s])},
aR(a,b,c){return new A.E(a,b,A.R(a).i("@<1>").C(c).i("E<1,2>"))},
bV(a,b,c){var s,r,q=a.length
for(s=b,r=0;r<q;++r){s=c.$2(s,a[r])
if(a.length!==q)throw A.a(A.a2(a))}return s},
bW(a,b,c){return this.bV(a,b,c,t.z)},
bT(a,b){var s,r,q=a.length
for(s=0;s<q;++s){r=a[s]
if(b.$1(r))return r
if(a.length!==q)throw A.a(A.a2(a))}throw A.a(A.fh())},
H(a,b){return a[b]},
gaN(a){if(a.length>0)return a[0]
throw A.a(A.fh())},
gA(a){var s=a.length
if(s>0)return a[s-1]
throw A.a(A.fh())},
aC(a,b){var s,r=a.length
for(s=0;s<r;++s){if(b.$1(a[s]))return!0
if(a.length!==r)throw A.a(A.a2(a))}return!1},
gaQ(a){return a.length!==0},
j(a){return A.fi(a,"[","]")},
gn(a){return new J.aB(a,a.length,A.R(a).i("aB<1>"))},
gq(a){return A.cd(a)},
gm(a){return a.length},
$ii:1,
$if:1}
J.bU.prototype={
cf(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.ce(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.db.prototype={}
J.aB.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s,r=this,q=r.a,p=q.length
if(r.b!==p)throw A.a(A.cK(q))
s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0}}
J.b3.prototype={
ag(a,b){var s
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=B.c.gP(b)
if(this.gP(a)===s)return 0
if(this.gP(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gP(a){return a===0?1/a<0:a<0},
bw(a){var s,r
if(a>=0){if(a<=2147483647){s=a|0
return a===s?s:s+1}}else if(a>=-2147483648)return a|0
r=Math.ceil(a)
if(isFinite(r))return r
throw A.a(A.cl(""+a+".ceil()"))},
bU(a){var s,r
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){s=a|0
return a===s?s:s-1}r=Math.floor(a)
if(isFinite(r))return r
throw A.a(A.cl(""+a+".floor()"))},
aV(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.a(A.cl(""+a+".round()"))},
bx(a,b,c){if(B.c.ag(b,c)>0)throw A.a(A.kn(b))
if(this.ag(a,b)<0)return b
if(this.ag(a,c)>0)return c
return a},
j(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gq(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
aZ(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
ab(a,b){return(a|0)===a?a/b|0:this.bo(a,b)},
bo(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.a(A.cl("Result of truncating division is "+A.u(s)+": "+A.u(a)+" ~/ "+b))},
az(a,b){var s
if(a>0)s=this.bm(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
bm(a,b){return b>31?0:a>>>b},
gt(a){return A.aw(t.H)},
$ib:1}
J.b1.prototype={
gt(a){return A.aw(t.S)},
$ip:1,
$id:1}
J.bW.prototype={
gt(a){return A.aw(t.i)},
$ip:1}
J.aE.prototype={
S(a,b,c){return a.substring(b,A.iW(b,c,a.length))},
b_(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.a(B.S)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
c3(a,b,c){var s=b-a.length
if(s<=0)return a
return this.b_(c,s)+a},
j(a){return a},
gq(a){var s,r,q
for(s=a.length,r=0,q=0;q<s;++q){r=r+a.charCodeAt(q)&536870911
r=r+((r&524287)<<10)&536870911
r^=r>>6}r=r+((r&67108863)<<3)&536870911
r^=r>>11
return r+((r&16383)<<15)&536870911},
gt(a){return A.aw(t.N)},
$ip:1,
$in:1}
A.aM.prototype={
gn(a){var s=this.a
return new A.bM(s.gn(s),A.Y(this).i("bM<1,2>"))},
gm(a){var s=this.a
return s.gm(s)},
gE(a){var s=this.a
return s.gE(s)},
j(a){return this.a.j(0)}}
A.bM.prototype={
l(){return this.a.l()},
gp(){return this.$ti.y[1].a(this.a.gp())}}
A.an.prototype={}
A.bn.prototype={$ii:1}
A.ao.prototype={
ad(a,b,c){return new A.ao(this.a,this.$ti.i("@<1,2>").C(b).C(c).i("ao<1,2,3,4>"))},
h(a,b){return this.$ti.i("4?").a(this.a.h(0,b))},
I(a,b){this.a.I(0,new A.d0(this,b))},
gJ(){var s=this.$ti
return A.iq(this.a.gJ(),s.c,s.y[2])},
gm(a){var s=this.a
return s.gm(s)},
gE(a){var s=this.a
return s.gE(s)}}
A.d0.prototype={
$2(a,b){var s=this.a.$ti
this.b.$2(s.y[2].a(a),s.y[3].a(b))},
$S(){return this.a.$ti.i("~(1,2)")}}
A.ag.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.ds.prototype={}
A.i.prototype={}
A.H.prototype={
gn(a){var s=this
return new A.aF(s,s.gm(s),A.Y(s).i("aF<H.E>"))},
gE(a){return this.gm(this)===0}}
A.bi.prototype={
b6(a,b,c,d){var s,r=this.b
A.fr(r,"start")
s=this.c
A.fr(s,"end")
if(r>s)throw A.a(A.aK(r,0,s,"start",null))},
gbg(){var s=this.a.length,r=this.c
if(r>s)return s
return r},
gbn(){var s=this.a.length,r=this.b
if(r>s)return s
return r},
gm(a){var s,r=this.a.length,q=this.b
if(q>=r)return 0
s=this.c
if(s>=r)return r-q
return s-q},
H(a,b){var s=this,r=s.gbn()+b,q=s.gbg()
if(r>=q)throw A.a(A.h6(b,s.gm(0),s,"index"))
return J.fR(s.a,r)}}
A.aF.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s,r=this,q=r.a,p=J.hU(q),o=p.gm(q)
if(r.b!==o)throw A.a(A.a2(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.H(q,s);++r.c
return!0}}
A.E.prototype={
gm(a){return J.ii(this.a)},
H(a,b){return this.b.$1(J.fR(this.a,b))}}
A.bl.prototype={
gn(a){return new A.co(J.bH(this.a),this.b)}}
A.co.prototype={
l(){var s,r
for(s=this.a,r=this.b;s.l();)if(r.$1(s.gp()))return!0
return!1},
gp(){return this.a.gp()}}
A.b_.prototype={}
A.cB.prototype={$r:"+(1,2)",$s:1}
A.bu.prototype={$r:"+a,b(1,2)",$s:2}
A.bv.prototype={$r:"+helium,nitrogen(1,2)",$s:3}
A.cC.prototype={$r:"+crush,gradient,radius(1,2,3)",$s:4}
A.a6.prototype={$r:"+high,intercept,low,slope(1,2,3,4)",$s:5}
A.dn.prototype={
$0(){return B.i.bU(1000*this.a.now())},
$S:16}
A.be.prototype={}
A.dE.prototype={
F(a){var s,r,q=this,p=new RegExp(q.a).exec(a)
if(p==null)return null
s=Object.create(null)
r=q.b
if(r!==-1)s.arguments=p[r+1]
r=q.c
if(r!==-1)s.argumentsExpr=p[r+1]
r=q.d
if(r!==-1)s.expr=p[r+1]
r=q.e
if(r!==-1)s.method=p[r+1]
r=q.f
if(r!==-1)s.receiver=p[r+1]
return s}}
A.bc.prototype={
j(a){return"Null check operator used on a null value"}}
A.bX.prototype={
j(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.ck.prototype={
j(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.di.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.aZ.prototype={}
A.bx.prototype={
j(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$iak:1}
A.ap.prototype={
j(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.i4(r==null?"unknown":r)+"'"},
gcj(){return this},
$C:"$1",
$R:1,
$D:null}
A.d2.prototype={$C:"$0",$R:0}
A.d3.prototype={$C:"$2",$R:2}
A.dx.prototype={}
A.dt.prototype={
j(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.i4(s)+"'"}}
A.aX.prototype={
G(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.aX))return!1
return this.$_target===b.$_target&&this.a===b.a},
gq(a){return(A.hX(this.a)^A.cd(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.ce(this.a)+"'")}}
A.ci.prototype={
j(a){return"RuntimeError: "+this.a}}
A.a9.prototype={
gm(a){return this.a},
gE(a){return this.a===0},
gJ(){return new A.aq(this,A.Y(this).i("aq<1>"))},
N(a,b){b.I(0,new A.dc(this))},
h(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.bY(b)},
bY(a){var s,r,q=this.d
if(q==null)return null
s=q[this.aO(a)]
r=this.aP(s,a)
if(r<0)return null
return s[r].b},
M(a,b,c){var s,r,q=this
if(typeof b=="string"){s=q.b
q.am(s==null?q.b=q.a9():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.am(r==null?q.c=q.a9():r,b,c)}else q.bZ(b,c)},
bZ(a,b){var s,r,q,p=this,o=p.d
if(o==null)o=p.d=p.a9()
s=p.aO(a)
r=o[s]
if(r==null)o[s]=[p.a1(a,b)]
else{q=p.aP(r,a)
if(q>=0)r[q].b=b
else r.push(p.a1(a,b))}},
I(a,b){var s=this,r=s.e,q=s.r
while(r!=null){b.$2(r.a,r.b)
if(q!==s.r)throw A.a(A.a2(s))
r=r.c}},
am(a,b,c){var s=a[b]
if(s==null)a[b]=this.a1(b,c)
else s.b=c},
a1(a,b){var s=this,r=new A.dg(a,b)
if(s.e==null)s.e=s.f=r
else s.f=s.f.c=r;++s.a
s.r=s.r+1&1073741823
return r},
aO(a){return J.a1(a)&1073741823},
aP(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.a0(a[r].a,b))return r
return-1},
j(a){return A.hb(this)},
a9(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s}}
A.dc.prototype={
$2(a,b){this.a.M(0,a,b)},
$S(){return A.Y(this.a).i("~(1,2)")}}
A.dg.prototype={}
A.aq.prototype={
gm(a){return this.a.a},
gE(a){return this.a.a===0},
gn(a){var s=this.a
return new A.c_(s,s.r,s.e)}}
A.c_.prototype={
gp(){return this.d},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.a(A.a2(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}}}
A.C.prototype={
gn(a){var s=this.a
return new A.bZ(s,s.r,s.e,this.$ti.i("bZ<1,2>"))}}
A.bZ.prototype={
gp(){var s=this.d
s.toString
return s},
l(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.a(A.a2(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.ai(s.a,s.b,r.$ti.i("ai<1,2>"))
r.c=s.c
return!0}}}
A.eV.prototype={
$1(a){return this.a(a)},
$S:12}
A.eW.prototype={
$2(a,b){return this.a(a,b)},
$S:39}
A.eX.prototype={
$1(a){return this.a(a)},
$S:32}
A.bt.prototype={
j(a){return this.aB(!1)},
aB(a){var s,r,q,p,o,n=this.bh(),m=this.V(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
o=m[q]
l=a?l+A.hh(o):l+A.u(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
bh(){var s,r=this.$s
while($.em.length<=r)$.em.push(null)
s=$.em[r]
if(s==null){s=this.be()
$.em[r]=s}return s},
be(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.b0(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
j[q]=r[s]}}return A.ar(j,k)}}
A.cy.prototype={
V(){return[this.a,this.b]},
G(a,b){if(b==null)return!1
return b instanceof A.cy&&this.$s===b.$s&&J.a0(this.a,b.a)&&J.a0(this.b,b.b)},
gq(a){return A.fn(this.$s,this.a,this.b,B.m)}}
A.cz.prototype={
V(){return[this.a,this.b,this.c]},
G(a,b){var s=this
if(b==null)return!1
return b instanceof A.cz&&s.$s===b.$s&&J.a0(s.a,b.a)&&J.a0(s.b,b.b)&&J.a0(s.c,b.c)},
gq(a){var s=this
return A.fn(s.$s,s.a,s.b,s.c)}}
A.cA.prototype={
V(){return this.a},
G(a,b){if(b==null)return!1
return b instanceof A.cA&&this.$s===b.$s&&A.ji(this.a,b.a)},
gq(a){return A.fn(this.$s,A.iO(this.a),B.m,B.m)}}
A.e4.prototype={
saM(a){if(this.b!==this)throw A.a(new A.ag("Local '' has already been initialized."))
this.b=a}}
A.aG.prototype={
gt(a){return B.b2},
$ip:1}
A.ba.prototype={}
A.c0.prototype={
gt(a){return B.b3},
$ip:1}
A.aH.prototype={
gm(a){return a.length},
$iO:1}
A.b8.prototype={$ii:1,$if:1}
A.b9.prototype={$ii:1,$if:1}
A.c1.prototype={
gt(a){return B.b4},
$ip:1}
A.c2.prototype={
gt(a){return B.b5},
$ip:1}
A.c3.prototype={
gt(a){return B.b6},
$ip:1}
A.c4.prototype={
gt(a){return B.b7},
$ip:1}
A.c5.prototype={
gt(a){return B.b8},
$ip:1}
A.c6.prototype={
gt(a){return B.ba},
$ip:1}
A.c7.prototype={
gt(a){return B.bb},
$ip:1}
A.bb.prototype={
gt(a){return B.bc},
gm(a){return a.length},
$ip:1}
A.c8.prototype={
gt(a){return B.bd},
gm(a){return a.length},
$ip:1}
A.bp.prototype={}
A.bq.prototype={}
A.br.prototype={}
A.bs.prototype={}
A.X.prototype={
i(a){return A.bD(v.typeUniverse,this,a)},
C(a){return A.hy(v.typeUniverse,this,a)}}
A.cu.prototype={}
A.er.prototype={
j(a){return A.P(this.a,null)}}
A.ct.prototype={
j(a){return this.a}}
A.bz.prototype={$iac:1}
A.e1.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:9}
A.e0.prototype={
$1(a){var s,r
this.a.a=a
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:31}
A.e2.prototype={
$0(){this.a.$0()},
$S:11}
A.e3.prototype={
$0(){this.a.$0()},
$S:11}
A.ep.prototype={
b9(a,b){if(self.setTimeout!=null)self.setTimeout(A.eQ(new A.eq(this,b),0),a)
else throw A.a(A.cl("`setTimeout()` not found."))}}
A.eq.prototype={
$0(){this.b.$0()},
$S:0}
A.cq.prototype={
ah(a){var s,r=this
if(a==null)a=r.$ti.c.a(a)
if(!r.b)r.a.ap(a)
else{s=r.a
if(r.$ti.i("ae<1>").b(a))s.aq(a)
else s.ar(a)}},
aH(a,b){var s=this.a
if(this.b)s.a6(new A.S(a,b))
else s.a4(new A.S(a,b))}}
A.eF.prototype={
$1(a){return this.a.$2(0,a)},
$S:29}
A.eG.prototype={
$2(a,b){this.a.$2(1,new A.aZ(a,b))},
$S:28}
A.eO.prototype={
$2(a,b){this.a(a,b)},
$S:26}
A.by.prototype={
gp(){return this.b},
bk(a,b){var s,r,q
a=a
b=b
s=this.a
for(;;)try{r=s(this,a,b)
return r}catch(q){b=q
a=1}},
l(){var s,r,q,p,o=this,n=null,m=0
for(;;){s=o.d
if(s!=null)try{if(s.l()){o.b=s.gp()
return!0}else o.d=null}catch(r){n=r
m=1
o.d=null}q=o.bk(m,n)
if(1===q)return!0
if(0===q){o.b=null
p=o.e
if(p==null||p.length===0){o.a=A.ht
return!1}o.a=p.pop()
m=0
n=null
continue}if(2===q){m=0
n=null
continue}if(3===q){n=o.c
o.c=null
p=o.e
if(p==null||p.length===0){o.b=null
o.a=A.ht
throw n
return!1}o.a=p.pop()
m=1
continue}throw A.a(A.fu("sync*"))}return!1},
ck(a){var s,r,q=this
if(a instanceof A.aP){s=a.a()
r=q.e
if(r==null)r=q.e=[]
r.push(q.a)
q.a=s
return 2}else{q.d=J.bH(a)
return 2}}}
A.aP.prototype={
gn(a){return new A.by(this.a())}}
A.S.prototype={
j(a){return A.u(this.a)},
$it:1,
gR(){return this.b}}
A.cs.prototype={
aH(a,b){var s=this.a
if((s.a&30)!==0)throw A.a(A.fu("Future already completed"))
s.a4(A.jU(a,b))}}
A.bm.prototype={
ah(a){var s=this.a
if((s.a&30)!==0)throw A.a(A.fu("Future already completed"))
s.ap(a)}}
A.aN.prototype={
c1(a){if((this.c&15)!==6)return!0
return this.b.b.ak(this.d,a.a)},
bX(a){var s,r=this.e,q=null,p=a.a,o=this.b.b
if(t.Q.b(r))q=o.cb(r,p,a.b)
else q=o.ak(r,p)
try{p=q
return p}catch(s){if(t.c.b(A.a_(s))){if((this.c&1)!==0)throw A.a(A.aW("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.a(A.aW("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.F.prototype={
aW(a,b,c){var s,r=$.x
if(r===B.h){if(!t.Q.b(b)&&!t.v.b(b))throw A.a(A.fc(b,"onError",u.c))}else b=A.kb(b,r)
s=new A.F(r,c.i("F<0>"))
this.a2(new A.aN(s,3,a,b,this.$ti.i("@<1>").C(c).i("aN<1,2>")))
return s},
aA(a,b,c){var s=new A.F($.x,c.i("F<0>"))
this.a2(new A.aN(s,19,a,b,this.$ti.i("@<1>").C(c).i("aN<1,2>")))
return s},
bl(a){this.a=this.a&1|16
this.c=a},
T(a){this.a=a.a&30|this.a&1
this.c=a.c},
a2(a){var s=this,r=s.a
if(r<=3){a.a=s.c
s.c=a}else{if((r&4)!==0){r=s.c
if((r.a&24)===0){r.a2(a)
return}s.T(r)}A.cJ(null,null,s.b,new A.e7(s,a))}},
aw(a){var s,r,q,p,o,n=this,m={}
m.a=a
if(a==null)return
s=n.a
if(s<=3){r=n.c
n.c=a
if(r!=null){q=a.a
for(p=a;q!=null;p=q,q=o)o=q.a
p.a=r}}else{if((s&4)!==0){s=n.c
if((s.a&24)===0){s.aw(a)
return}n.T(s)}m.a=n.X(a)
A.cJ(null,null,n.b,new A.eb(m,n))}},
W(){var s=this.c
this.c=null
return this.X(s)},
X(a){var s,r,q
for(s=a,r=null;s!=null;r=s,s=q){q=s.a
s.a=r}return r},
ar(a){var s=this,r=s.W()
s.a=8
s.c=a
A.aO(s,r)},
bd(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.W()
q.T(a)
A.aO(q,r)},
a6(a){var s=this.W()
this.bl(a)
A.aO(this,s)},
ap(a){if(this.$ti.i("ae<1>").b(a)){this.aq(a)
return}this.bc(a)},
bc(a){this.a^=2
A.cJ(null,null,this.b,new A.e9(this,a))},
aq(a){A.fw(a,this,!1)
return},
a4(a){this.a^=2
A.cJ(null,null,this.b,new A.e8(this,a))},
$iae:1}
A.e7.prototype={
$0(){A.aO(this.a,this.b)},
$S:0}
A.eb.prototype={
$0(){A.aO(this.b,this.a.a)},
$S:0}
A.ea.prototype={
$0(){A.fw(this.a.a,this.b,!0)},
$S:0}
A.e9.prototype={
$0(){this.a.ar(this.b)},
$S:0}
A.e8.prototype={
$0(){this.a.a6(this.b)},
$S:0}
A.ee.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.c9(q.d)}catch(p){s=A.a_(p)
r=A.aT(p)
if(k.c&&k.b.a.c.a===s){q=k.a
q.c=k.b.a.c}else{q=s
o=r
if(o==null)o=A.fd(q)
n=k.a
n.c=new A.S(q,o)
q=n}q.b=!0
return}if(j instanceof A.F&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=j.c
q.b=!0}return}if(j instanceof A.F){m=k.b.a
l=new A.F(m.b,m.$ti)
j.aW(new A.ef(l,m),new A.eg(l),t.o)
q=k.a
q.c=l
q.b=!1}},
$S:0}
A.ef.prototype={
$1(a){this.a.bd(this.b)},
$S:9}
A.eg.prototype={
$2(a,b){this.a.a6(new A.S(a,b))},
$S:23}
A.ed.prototype={
$0(){var s,r,q,p,o,n
try{q=this.a
p=q.a
q.c=p.b.b.ak(p.d,this.b)}catch(o){s=A.a_(o)
r=A.aT(o)
q=s
p=r
if(p==null)p=A.fd(q)
n=this.a
n.c=new A.S(q,p)
n.b=!0}},
$S:0}
A.ec.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=l.a.a.c
p=l.b
if(p.a.c1(s)&&p.a.e!=null){p.c=p.a.bX(s)
p.b=!1}}catch(o){r=A.a_(o)
q=A.aT(o)
p=l.a.a.c
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.fd(p)
m=l.b
m.c=new A.S(p,n)
p=m}p.b=!0}},
$S:0}
A.cr.prototype={}
A.cD.prototype={}
A.eC.prototype={}
A.en.prototype={
cd(a){var s,r,q
try{if(B.h===$.x){a.$0()
return}A.hI(null,null,this,a)}catch(q){s=A.a_(q)
r=A.aT(q)
A.fC(s,r)}},
bs(a){return new A.eo(this,a)},
ca(a){if($.x===B.h)return a.$0()
return A.hI(null,null,this,a)},
c9(a){return this.ca(a,t.z)},
ce(a,b){if($.x===B.h)return a.$1(b)
return A.kd(null,null,this,a,b)},
ak(a,b){var s=t.z
return this.ce(a,b,s,s)},
cc(a,b,c){if($.x===B.h)return a.$2(b,c)
return A.kc(null,null,this,a,b,c)},
cb(a,b,c){var s=t.z
return this.cc(a,b,c,s,s,s)},
c7(a){return a},
aU(a){var s=t.z
return this.c7(a,s,s,s)}}
A.eo.prototype={
$0(){return this.a.cd(this.b)},
$S:0}
A.eN.prototype={
$0(){A.iy(this.a,this.b)},
$S:0}
A.bo.prototype={
gn(a){var s=this,r=new A.cx(s,s.r,A.Y(s).i("cx<1>"))
r.c=s.e
return r},
bq(a,b){var s,r,q=this
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.an(s==null?q.b=A.fx():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.an(r==null?q.c=A.fx():r,b)}else return q.ba(b)},
ba(a){var s,r,q=this,p=q.d
if(p==null)p=q.d=A.fx()
s=q.bf(a)
r=p[s]
if(r==null)p[s]=[q.aa(a)]
else{if(q.bi(r,a)>=0)return!1
r.push(q.aa(a))}return!0},
an(a,b){if(a[b]!=null)return!1
a[b]=this.aa(b)
return!0},
aa(a){var s=this,r=new A.el(a)
if(s.e==null)s.e=s.f=r
else s.f=s.f.b=r;++s.a
s.r=s.r+1&1073741823
return r},
bf(a){return J.a1(a)&1073741823},
bi(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.a0(a[r].a,b))return r
return-1}}
A.el.prototype={}
A.cx.prototype={
gp(){var s=this.d
return s==null?this.$ti.c.a(s):s},
l(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.a(A.a2(q))
else if(r==null){s.d=null
return!1}else{s.d=r.a
s.c=r.b
return!0}}}
A.v.prototype={
gn(a){return new A.aF(a,a.length,A.aU(a).i("aF<v.E>"))},
H(a,b){return a[b]},
gaQ(a){return a.length!==0},
aR(a,b,c){return new A.E(a,b,A.aU(a).i("@<v.E>").C(c).i("E<1,2>"))},
j(a){return A.fi(a,"[","]")}}
A.I.prototype={
ad(a,b,c){return new A.ao(this,A.Y(this).i("@<I.K,I.V>").C(b).C(c).i("ao<1,2,3,4>"))},
I(a,b){var s,r,q,p
for(s=this.gJ(),s=s.gn(s),r=A.Y(this).i("I.V");s.l();){q=s.gp()
p=this.h(0,q)
b.$2(q,p==null?r.a(p):p)}},
gm(a){var s=this.gJ()
return s.gm(s)},
gE(a){var s=this.gJ()
return s.gE(s)},
j(a){return A.hb(this)},
$iD:1}
A.dh.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.u(a)
r.a=(r.a+=s)+": "
s=A.u(b)
r.a+=s},
$S:14}
A.aL.prototype={
j(a){return A.fi(this,"{","}")},
$ii:1}
A.bw.prototype={}
A.cv.prototype={
h(a,b){var s,r=this.b
if(r==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.bj(b):s}},
gm(a){return this.b==null?this.c.a:this.U().length},
gE(a){return this.gm(0)===0},
gJ(){if(this.b==null){var s=this.c
return new A.aq(s,A.Y(s).i("aq<1>"))}return new A.cw(this)},
I(a,b){var s,r,q,p,o=this
if(o.b==null)return o.c.I(0,b)
s=o.U()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.eM(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.a(A.a2(o))}},
U(){var s=this.c
if(s==null)s=this.c=A.k(Object.keys(this.a),t.s)
return s},
bj(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.eM(this.a[a])
return this.b[a]=s}}
A.cw.prototype={
gm(a){return this.a.gm(0)},
H(a,b){var s=this.a
return s.b==null?s.gJ().H(0,b):s.U()[b]},
gn(a){var s=this.a
if(s.b==null){s=s.gJ()
s=s.gn(s)}else{s=s.U()
s=new J.aB(s,s.length,A.R(s).i("aB<1>"))}return s}}
A.bN.prototype={}
A.bP.prototype={}
A.b7.prototype={
j(a){var s=A.bR(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.bY.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.dd.prototype={
bM(a,b){var s=A.k9(a,this.gbN().a)
return s},
bP(a,b){var s=A.jb(a,this.gbQ().b,null)
return s},
gbQ(){return B.aN},
gbN(){return B.aM}}
A.df.prototype={}
A.de.prototype={}
A.ej.prototype={
aY(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.o.S(a,r,q)
r=q+1
o=A.K(92)
s.a+=o
o=A.K(117)
s.a+=o
o=A.K(100)
s.a+=o
o=p>>>8&15
o=A.K(o<10?48+o:87+o)
s.a+=o
o=p>>>4&15
o=A.K(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.K(o<10?48+o:87+o)
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.o.S(a,r,q)
r=q+1
o=A.K(92)
s.a+=o
switch(p){case 8:o=A.K(98)
s.a+=o
break
case 9:o=A.K(116)
s.a+=o
break
case 10:o=A.K(110)
s.a+=o
break
case 12:o=A.K(102)
s.a+=o
break
case 13:o=A.K(114)
s.a+=o
break
default:o=A.K(117)
s.a+=o
o=A.K(48)
s.a=(s.a+=o)+o
o=p>>>4&15
o=A.K(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.K(o<10?48+o:87+o)
s.a+=o
break}}else if(p===34||p===92){if(q>r)s.a+=B.o.S(a,r,q)
r=q+1
o=A.K(92)
s.a+=o
o=A.K(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.o.S(a,r,m)},
a5(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.a(new A.bY(a,null))}s.push(a)},
a_(a){var s,r,q,p,o=this
if(o.aX(a))return
o.a5(a)
try{s=o.b.$1(a)
if(!o.aX(s)){q=A.h8(a,null,o.gau())
throw A.a(q)}o.a.pop()}catch(p){r=A.a_(p)
q=A.h8(a,r,o.gau())
throw A.a(q)}},
aX(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.i.j(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.aY(a)
s.a+='"'
return!0}else if(t.j.b(a)){q.a5(a)
q.cg(a)
q.a.pop()
return!0}else if(a instanceof A.I){q.a5(a)
r=q.ci(a)
q.a.pop()
return r}else return!1},
cg(a){var s,r=this.c
r.a+="["
if(J.ih(a)){this.a_(a[0])
for(s=1;s<a.length;++s){r.a+=","
this.a_(a[s])}}r.a+="]"},
ci(a){var s,r,q,p,o,n=this,m={}
if(a.gE(a)){n.c.a+="{}"
return!0}s=a.gm(a)*2
r=A.a4(s,null,!1,t.X)
q=m.a=0
m.b=!0
a.I(0,new A.ek(m,r))
if(!m.b)return!1
p=n.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
n.aY(A.eE(r[q]))
p.a+='":'
n.a_(r[q+1])}p.a+="}"
return!0}}
A.ek.prototype={
$2(a,b){var s,r,q,p
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
q=r.a
p=r.a=q+1
s[q]=a
r.a=p+1
s[p]=b},
$S:14}
A.ei.prototype={
gau(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.aD.prototype={
G(a,b){if(b==null)return!1
return b instanceof A.aD&&this.a===b.a},
gq(a){return B.c.gq(this.a)},
j(a){var s,r,q,p,o,n=this.a,m=B.c.ab(n,36e8),l=n%36e8
if(n<0){m=0-m
n=0-l
s="-"}else{n=l
s=""}r=B.c.ab(n,6e7)
n%=6e7
q=r<10?"0":""
p=B.c.ab(n,1e6)
o=p<10?"0":""
return s+m+":"+q+r+":"+o+p+"."+B.o.c3(B.c.j(n%1e6),6,"0")}}
A.e5.prototype={
j(a){return this.K()}}
A.t.prototype={
gR(){return A.iT(this)}}
A.bJ.prototype={
j(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.bR(s)
return"Assertion failed"}}
A.ac.prototype={}
A.a7.prototype={
ga8(){return"Invalid argument"+(!this.a?"(s)":"")},
ga7(){return""},
j(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.ga8()+q+o
if(!s.a)return n
return n+s.ga7()+": "+A.bR(s.gai())},
gai(){return this.b}}
A.cg.prototype={
gai(){return this.b},
ga8(){return"RangeError"},
ga7(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.u(q):""
else if(q==null)s=": Not greater than or equal to "+A.u(r)
else if(q>r)s=": Not in inclusive range "+A.u(r)+".."+A.u(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.u(r)
return s}}
A.bS.prototype={
gai(){return this.b},
ga8(){return"RangeError"},
ga7(){if(this.b<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s}}
A.bk.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.cj.prototype={
j(a){return"UnimplementedError: "+this.a}}
A.bg.prototype={
j(a){return"Bad state: "+this.a}}
A.bO.prototype={
j(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bR(s)+"."}}
A.c9.prototype={
j(a){return"Out of Memory"},
gR(){return null},
$it:1}
A.bf.prototype={
j(a){return"Stack Overflow"},
gR(){return null},
$it:1}
A.e6.prototype={
j(a){return"Exception: "+this.a}}
A.d8.prototype={
j(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException"
return r}}
A.G.prototype={
bR(a,b){var s
for(s=this.gn(this);s.l();)if(!b.$1(s.gp()))return!1
return!0},
gm(a){var s,r=this.gn(this)
for(s=0;r.l();)++s
return s},
H(a,b){var s,r
A.fr(b,"index")
s=this.gn(this)
for(r=b;s.l();){if(r===0)return s.gp();--r}throw A.a(A.h6(b,b-r,this,"index"))},
j(a){return A.iE(this,"(",")")}}
A.ai.prototype={
j(a){return"MapEntry("+A.u(this.a)+": "+A.u(this.b)+")"}}
A.J.prototype={
gq(a){return A.h.prototype.gq.call(this,0)},
j(a){return"null"}}
A.h.prototype={$ih:1,
G(a,b){return this===b},
gq(a){return A.cd(this)},
j(a){return"Instance of '"+A.ce(this)+"'"},
gt(a){return A.kz(this)},
toString(){return this.j(this)}}
A.cE.prototype={
j(a){return""},
$iak:1}
A.dv.prototype={
gbO(){var s,r=this.b
if(r==null)r=$.fq.$0()
s=r-this.a
if($.fP()===1e6)return s
return s*1000}}
A.bh.prototype={
j(a){var s=this.a
return s.charCodeAt(0)==0?s:s}}
A.da.prototype={
br(a,b){var s,r=this
A.c(a,"depthMetres",!0)
A.c(b,"firstStopMetres",!0)
if(b===0||a===0)return r.b
if(a>=b)return r.a
s=r.b
return s+(r.a-s)*B.i.bx(a/b,0,1)}}
A.d1.prototype={}
A.cT.prototype={
c2(a,b){var s,r=a.a[b],q=a.b[b],p=r+q
if(p===0)return B.aV
s=this.a
return new A.bu((r*s.b[b]+q*s.d[b])/p,(r*s.c[b]+q*s.e[b])/p)},
Y(a,b,c){var s,r,q,p,o,n,m,l,k
A.c(b,"gradient factor",!1)
if(b<=0||b>1)throw A.a(B.aa)
s=A.k([],t.n)
for(r=a.a,q=a.b,p=0,o=0;o<16;++o){n=r[o]+q[o]
m=this.c2(a,o)
l=n===0?0:Math.max(0,(n-b*m.a)/(b/m.b-b+1))
if(isFinite(l))k=l<0
else k=!0
if(k)A.j(A.o(B.a,"tissue ceiling must be finite and nonnegative.",0))
s.push(l)
if(l>p)p=l}r=Math.max(0,c.aL(p))
A.ar(s,t.i)
return new A.d1(r)},
bS(a,b,c,d,e,f,g,h){var s,r,q,p,o,n,m=this
A.c(d,"currentDepthMetres",!0)
A.c(a,"ascentMetresPerMin",!0)
if(a===0)throw A.a(B.D)
s=e.a
r=f.aE(m.Y(h,s,g).b)
for(q=f.a,p=m.a.f,o=f.b;r<=d;){c.u();++c.e
if(m.Y(p.B(b,(d-r)/a,r,h,g,d),s,g).b<=r){for(;r>0;r=n){c.u();++c.e
n=f.aj(r)
if(m.Y(p.B(b,(d-n)/a,n,h,g,d),s,g).b>n)break}return r}r=r===0?o:r+q}throw A.a(B.ak)}}
A.cR.prototype={}
A.cM.prototype={
b1(a,b,c,d,e,f,g){var s,r,q,p,o,n,m,l,k=this
for(s=k.r,r=k.c,q=k.d,p=k.e,o=A.m(["seaLevelBar",s,"diveAltitudeMetres",r,"initialAltitudeMetres",q,"travelMin",p,"waitMin",k.f],t.N,t.i),o=new A.C(o,o.$ti.i("C<1,2>")).gn(0);o.l();){n=o.d
m=n.b
l=n.a
if(isFinite(m))m=m<0
else m=!0
if(m)A.j(A.o(B.a,l+" must be finite and nonnegative.",0))}if(s===0)throw A.a(B.aj)
s=!1
if(k.a)if(!k.b)s=q>=r||p===0
if(s)throw A.a(B.a4)},
k(){var s=this
return A.m(["enabled",s.a,"seaLevelBar",s.r,"acclimatized",s.b,"diveAltitudeMetres",s.c,"initialAltitudeMetres",s.d,"travelMin",s.e,"waitMin",s.f],t.N,t.X)}}
A.U.prototype={
k(){var s=this.a.k(),r=this.b.k(),q=this.c
return A.m(["tissues",s,"oxygen",r,"vpm",q==null?null:q.k()],t.N,t.X)}}
A.d9.prototype={
k(){return A.m(["oxygen",this.a,"helium",this.b],t.N,t.K)}}
A.aY.prototype={
K(){return"BreathingMode."+this.b}}
A.a8.prototype={
k(){return A.m(["mode",this.b.b,"gas",this.a.k(),"setpointBar",this.c],t.N,t.X)}}
A.bL.prototype={
b2(a,b,c,d,e){var s=this
if(s.a.length===0||s.b.length===0)throw A.a(B.af)
A.c(s.c,"bailout runtimeMin",!0)
if(B.b.aC(s.e,new A.cP()))throw A.a(B.ai)},
k(){var s=this,r=s.d.k(),q=s.e,p=A.R(q).i("E<1,D<n,h?>>")
q=A.W(new A.E(q,new A.cQ(),p),p.i("H.E"))
return A.m(["id",s.a,"sourceDiveId",s.b,"runtimeMin",s.c,"initialOcGas",r,"switches",q],t.N,t.X)}}
A.cP.prototype={
$1(a){return a.b.b!==B.e},
$S:15}
A.cQ.prototype={
$1(a){return a.k()},
$S:18}
A.cO.prototype={
$1(a){return A.h4(A.M(a,"switch"))},
$S:17}
A.aC.prototype={
K(){return"DecompressionModel."+this.b}}
A.cZ.prototype={
b4(a,b,c,d,e,f,g,h,i,j,a0,a1,a2,a3,a4,a5){var s,r,q,p,o,n,m,l,k=this
for(s=k.r,r=k.w,q=k.x,p=k.z,o=A.m(["descentMetresPerMin",s,"ascentMetresPerMin",r,"minimumStopMin",q,"lowSetpointBar",p,"bottomRmvLitresPerMin",k.as,"decoRmvLitresPerMin",k.at,"bottomOxygenLitresPerMin",k.ax,"decoOxygenLitresPerMin",k.ay],t.N,t.i),o=new A.C(o,o.$ti.i("C<1,2>")).gn(0);o.l();){n=o.d
m=n.b
l=n.a
if(isFinite(m))m=m<0
else m=!0
if(m)A.j(A.o(B.a,l+" must be finite and nonnegative.",0))}o=!0
if(s!==0)if(r!==0)if(q!==0)if(p!==0){s=k.Q
s=s<0||s>4}else s=o
else s=o
else s=o
else s=o
if(s)throw A.a(B.Z)},
k(){var s=this,r=s.d,q=s.e,p=s.f
return A.m(["model",s.a.b,"vpm",s.b.k(),"altitude",s.c.k(),"surfaceBar",r.a,"waterVapourBar",r.b,"barPerMetre",r.c,"stepMetres",q.a,"lastStopMetres",q.b,"gfLow",p.a,"gfHigh",p.b,"descentMetresPerMin",s.r,"ascentMetresPerMin",s.w,"minimumStopMin",s.x,"includeDescentInLevelTime",s.y,"lowSetpointBar",s.z,"vpmConservatism",s.Q,"bottomRmvLitresPerMin",s.as,"decoRmvLitresPerMin",s.at,"bottomOxygenLitresPerMin",s.ax,"decoOxygenLitresPerMin",s.ay],t.N,t.X)}}
A.d_.prototype={
$1(a){return A.y(this.a.h(0,a),a)},
$S:6}
A.a3.prototype={
k(){return A.m(["depthMetres",this.a,"durationMin",this.b,"breathing",this.c.k()],t.N,t.X)}}
A.V.prototype={
k(){var s=this
return A.m(["depthMetres",s.a,"breathing",s.b.k(),"lost",s.c,"minimumStopMin",s.d],t.N,t.X)}}
A.bQ.prototype={
k(){var s,r,q=this,p=q.b,o=A.R(p).i("E<1,D<n,h?>>")
p=A.W(new A.E(p,new A.d6(),o),o.i("H.E"))
o=q.c
s=A.R(o).i("E<1,D<n,h?>>")
o=A.W(new A.E(o,new A.d7(),s),s.i("H.E"))
s=q.d.k()
r=q.f
r=r==null?null:r.k()
return A.m(["id",q.a,"levels",p,"switches",o,"settings",s,"surfaceIntervalMin",q.e,"initialState",r],t.N,t.X)}}
A.d6.prototype={
$1(a){return a.k()},
$S:22}
A.d7.prototype={
$1(a){return a.k()},
$S:18}
A.d4.prototype={
$1(a){var s="depthMetres",r="durationMin",q="breathing",p=A.M(a,"level"),o=A.y(p.h(0,s),s),n=A.y(p.h(0,r),r)
return A.h9(A.fY(A.M(p.h(0,q),q)),o,n)},
$S:21}
A.d5.prototype={
$1(a){return A.h4(A.M(a,"switch"))},
$S:17}
A.aj.prototype={
K(){return"SegmentPhase."+this.b}}
A.a5.prototype={
k(){var s=this,r=s.a
return A.m(["startDepthMetres",r.a,"endDepthMetres",r.b,"durationMin",r.c,"breathing",r.d.k(),"phase",s.b.b,"startMin",s.c,"endState",s.d.k()],t.N,t.X)}}
A.cX.prototype={
b3(a,b,c,d,e,f,g,a0){var s,r,q,p,o,n,m,l,k,j,i,h=this
if(h.a.length===0||h.b.length===0)throw A.a(B.a9)
for(s=h.r,r=h.w,q=A.m(["firstStopMetres",h.f,"ascentMin",s,"decompressionMin",r],t.N,t.i),q=new A.C(q,q.$ti.i("C<1,2>")).gn(0);q.l();){p=q.d
o=p.b
n=p.a
if(isFinite(o))o=o<0
else o=!0
if(o)A.j(A.o(B.a,n+" must be finite and nonnegative.",0))}for(q=h.e,o=q.length,m=0,l=0,k=0;k<o;++k){j=q[k]
n=j.c
if(n!==m||j.a.a!==l)throw A.a(B.ac)
i=j.a
m=n+i.c
l=i.b}if(r>s||s>m)throw A.a(B.aD)},
gO(){var s=this.e
return s.length===0?this.c:B.b.gA(s).d},
k(){var s,r,q=this,p=q.c.k(),o=q.d,n=t.N
o=A.m(["surfaceBar",o.a,"waterVapourBar",o.b,"barPerMetre",o.c],n,t.i)
s=q.e
r=A.R(s).i("E<1,D<n,h?>>")
s=A.W(new A.E(s,new A.cY(),r),r.i("H.E"))
return A.m(["diveId",q.a,"modelVersion",q.b,"initialState",p,"pressure",o,"segments",s,"firstStopMetres",q.f,"ascentMin",q.r,"decompressionMin",q.w],n,t.X)}}
A.cY.prototype={
$1(a){return a.k()},
$S:43}
A.dO.prototype={
b7(a,b,c,d,e,f,g,h,i,j){var s,r,q,p,o,n,m,l=this
if(l.a.length===0)throw A.a(B.ap)
for(s=l.d,r=l.e,q=A.m(["nitrogenRadiusMetres",l.b,"heliumRadiusMetres",l.c,"surfaceTension",s,"skinCompression",r,"onsetImpermeabilityBar",l.f,"lambdaPascalMinutes",l.r,"regenerationMin",l.w,"otherGasesBar",l.x],t.N,t.i),q=new A.C(q,q.$ti.i("C<1,2>")).gn(0);q.l();){p=q.d
o=p.b
n=p.a
if(isFinite(o))m=o<0
else m=!0
if(m)A.j(A.o(B.a,n+" must be finite and nonnegative.",0))
if(o===0)throw A.a(A.o(B.a,n+" must be positive.",0))}if(r<=s)throw A.a(B.W)},
k(){var s=this
return A.m(["version",s.a,"nitrogenRadiusMetres",s.b,"heliumRadiusMetres",s.c,"surfaceTension",s.d,"skinCompression",s.e,"onsetImpermeabilityBar",s.f,"lambdaPascalMinutes",s.r,"regenerationMin",s.w,"otherGasesBar",s.x,"criticalVolumeEnabled",s.y],t.N,t.X)}}
A.dP.prototype={
$1(a){return A.y(this.a.h(0,a),a)},
$S:6}
A.dV.prototype={
b8(a,b,c,d,e,f,g,h,i,j,k,l,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2){var s,r,q,p,o,n,m=this
if(m.a.length===0||m.p1<0||m.p2<0)throw A.a(B.av)
for(s=m.go,r=m.id,q=A.m(["surfaceBar",s,"vapourBar",r,"otherGasesBar",m.k1,"maximumFirstStopMetres",m.k2,"decoZoneStartMin",m.k3,"savedRuntimeMin",m.k4,"decoPhaseVolumeMin",m.ok],t.N,t.i),q=new A.C(q,q.$ti.i("C<1,2>")).gn(0);q.l();){p=q.d
o=p.b
n=p.a
if(isFinite(o))o=o<0
else o=!0
if(o)A.j(A.o(B.a,n+" must be finite and nonnegative.",0))}if(s<=r)throw A.a(B.ar)},
v(b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3){var s=this,r=d0==null?s.b:d0,q=c9==null?s.c:c9,p=b6==null?s.d:b6,o=b5==null?s.e:b5,n=d3==null?s.f:d3,m=d2==null?s.r:d2,l=d7==null?s.w:d7,k=d6==null?s.x:d6,j=b4==null?s.y:b4,i=b3==null?s.z:b3,h=c8==null?s.Q:c8,g=c7==null?s.as:c7,f=b8==null?s.at:b8,e=b7==null?s.ax:b7,d=c2==null?s.ay:c2,c=c1==null?s.ch:c1,b=d1==null?s.CW:d1,a=e1==null?s.cx:e1,a0=e3==null?s.cy:e3,a1=d5==null?s.db:d5,a2=b9==null?s.dx:b9,a3=e2==null?s.dy:e2,a4=c5==null?s.fr:c5,a5=c0==null?s.fx:c0,a6=e0==null?s.fy:e0,a7=d4==null?s.k2:d4,a8=c6==null?s.k3:c6,a9=d8==null?s.k4:d8,b0=c4==null?s.ok:c4,b1=d9==null?s.p1:d9,b2=c3==null?s.p2:c3
return A.fv(i,j,o,p,e,f,a2,a5,c,d,b2,b0,a4,a8,g,h,q,r,b,m,n,a7,s.a,s.k1,a1,k,l,a9,b1,a6,s.go,a,a3,a0,s.id)},
bJ(a,b,c,d){var s=null
return this.v(s,s,a,b,s,s,s,s,s,s,s,s,s,s,s,s,c,d,s,s,s,s,s,s,s,s,s,s,s,s,s)},
aI(a){var s=null
return this.v(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,a,s,s,s,s,s,s,s,s,s)},
aJ(a,b){var s=null
return this.v(s,s,a,b,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},
bK(a,b,c,d,e){var s=null
return this.v(s,s,s,s,s,s,a,s,s,s,s,s,s,s,s,s,s,s,s,b,c,s,s,s,s,s,s,d,s,e,s)},
bC(a,b,c,d,e,f,g,h,i,j){var s=null
return this.v(s,s,s,s,s,s,s,a,s,s,b,c,d,e,s,s,s,s,s,s,s,s,f,s,s,g,h,s,i,s,j)},
by(a){var s=null
return this.v(s,s,s,s,s,s,s,s,s,s,a,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},
bF(a,b){var s=null
return this.v(s,s,s,s,s,s,s,s,s,s,s,a,s,s,s,s,s,s,s,s,s,s,b,s,s,s,s,s,s,s,s)},
bD(a,b){var s=null
return this.v(s,s,s,s,a,b,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},
bI(a,b,c){var s=null
return this.v(s,s,s,s,s,s,s,s,s,s,s,a,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,b,s,c)},
bE(a,b){var s=null
return this.v(s,s,s,s,s,s,s,s,a,b,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},
bA(a){var s=null
return this.v(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,a,s,s,s)},
bz(a){var s=null
return this.v(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,a,s,s,s,s,s,s,s,s,s,s,s,s)},
bB(a,b,c,d,e,f,g,h,i,j){var s=null
return this.v(a,b,s,s,c,d,s,s,e,f,s,s,s,s,g,h,s,s,s,s,s,s,s,i,j,s,s,s,s,s,s)},
bL(a,b,c,d,e,f){var s=null
return this.v(s,s,a,b,s,s,s,s,s,s,s,s,s,s,s,s,c,d,s,s,s,s,s,e,f,s,s,s,s,s,s)},
bH(a,b,c){var s=null
return this.v(s,s,s,s,s,s,s,a,s,s,s,s,b,s,s,s,s,s,s,s,s,s,s,s,s,s,s,c,s,s,s)},
bG(a,b){var s=null
return this.v(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,a,s,s,s,s,s,s,s,s,b,s,s,s)},
k(){var s=this
return A.m(["modelVersion",s.a,"initialRadiusNitrogenMetres",s.b,"initialRadiusHeliumMetres",s.c,"adjustedInitialRadiusNitrogenMetres",s.d,"adjustedInitialRadiusHeliumMetres",s.e,"maxCrushingPressureNitrogenBar",s.f,"maxCrushingPressureHeliumBar",s.r,"regeneratedRadiusNitrogenMetres",s.w,"regeneratedRadiusHeliumMetres",s.x,"adjustedCrushingPressureNitrogenBar",s.y,"adjustedCrushingPressureHeliumBar",s.z,"initialAllowableGradientNitrogenBar",s.Q,"initialAllowableGradientHeliumBar",s.as,"allowableGradientNitrogenBar",s.at,"allowableGradientHeliumBar",s.ax,"boyleGradientNitrogenBar",s.ay,"boyleGradientHeliumBar",s.ch,"maxActualGradientBar",s.CW,"surfacePhaseVolumeMin",s.cx,"totalPhaseVolumeMin",s.cy,"previousPhaseVolumeMin",s.db,"ambientOnsetBar",s.dx,"tensionOnsetBar",s.dy,"decoStartTissues",s.fr.k(),"ascentStartTissues",s.fx.k(),"segmentStartTissues",s.fy.k(),"surfaceBar",s.go,"vapourBar",s.id,"otherGasesBar",s.k1,"maximumFirstStopMetres",s.k2,"decoZoneStartMin",s.k3,"savedRuntimeMin",s.k4,"decoPhaseVolumeMin",s.ok,"savedSegmentCount",s.p1,"criticalVolumeIterations",s.p2],t.N,t.X)}}
A.dX.prototype={
$1(a){var s=this.a.h(0,a)
if(!t.j.b(s))A.A(a)
return J.aA(s,new A.dY(a),t.i)},
$S:20}
A.dY.prototype={
$1(a){return A.y(a,this.a)},
$S:2}
A.dW.prototype={
$1(a){return A.y(this.a.h(0,a),a)},
$S:6}
A.T.prototype={
K(){return"CalculationFailureCode."+this.b}}
A.e.prototype={
k(){return A.m(["code",this.a.b,"message",this.b,"iterations",this.c],t.N,t.X)},
j(a){return"CalculationFailure("+this.a.b+"): "+this.b}}
A.cU.prototype={
af(a){var s,r=this
if(A.h3(r.d.gbO()).a<r.b.a)s=a&&r.e>=r.a
else s=!0
if(s)throw A.a(A.o(B.q,"Calculation budget exhausted.",r.e))},
u(){return this.af(!0)},
L(){this.u();++this.e}}
A.bd.prototype={}
A.fa.prototype={
$1(a){var s,r=this.a
r.L()
s=this.b.$1(a)
r.af(!1)
if(!isFinite(s))throw A.a(A.o(B.B,"Nonfinite root function value.",r.e-this.c))
return s},
$S:1}
A.fb.prototype={
$2(a,b){return B.i.gP(a)!==B.i.gP(b)},
$S:5}
A.ca.prototype={
k(){var s=this.b
s=s==null?null:s.k()
return A.m(["cnsFraction",this.a,"otu",this.c,"cnsUnavailableReason",s],t.N,t.X)}}
A.dj.prototype={
$1(a){return this.a<=a.a[0]},
$S:24}
A.cN.prototype={}
A.f3.prototype={
$2(a,b){return Math.max(a,b.d.c.k2)},
$S:25}
A.eH.prototype={
$3(a,b,c){var s,r,q,p,o=this
if(b===0&&o.a.c===a)return
o.b.L()
s=o.a
r=s.c
q=A.dq(s.x,b,a,r)
r=o.d
s.a=q.Z(s.a,o.c.f,r)
p=A.fo(s.b,q,r)
s.b=p
r=s.d
o.e.push(A.ft(new A.U(s.a,p,null),c,q,r))
s.d+=b
s.c=a
if(c===B.l||c===B.k)s.f+=b
if(c===B.k)s.e+=b},
$S:13}
A.eK.prototype={
$2(a,b){return Math.abs(a-b)<=3552713678800501e-30*Math.max(1,Math.max(Math.abs(a),Math.abs(b)))},
$S:5}
A.eL.prototype={
$0(){var s,r,q,p,o,n,m,l
for(s=this.b.c,r=s.length,q=this.a,p=this.c,o=0;o<r;++o){n=s[o]
if(!n.c){m=n.a
l=q.c
m=m<l&&!p.$2(m,l)}else m=!0
if(m)continue
m=q.y
if(m==null||n.a<m.a){q.x=n.b
q.y=n}}},
$S:0}
A.eJ.prototype={
$1(a){var s,r,q,p,o,n,m,l,k
for(s=this.b.c,r=s.length,q=this.a,p=this.c,o=a,n=0;n<r;++n){m=s[n]
l=!1
if(!m.c){k=m.a
if(k<q.c)if(k>o)if(!p.$2(k,o)){l=q.y
l=l==null||k<l.a}}if(l)o=m.a}return o},
$S:1}
A.eI.prototype={
$1(a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=this,a3=a2.a,a4=a3.c
if(a4<=a5)return
s=a2.b
r=a3.a
q=a2.c
p=q.w
o=a2.d
n=a2.e
m=a2.f
l=a2.r
k=s.bS(p,a3.x,l,a4,o,m,n,r)
if(k<a5)k=a5
if(a3.w===0&&k>a5)a3.w=k
if(k>a3.r)a3.r=k
for(a4=a2.x,r=a2.z.f,j=a2.w,i=a2.y,h=q.x,g=!1;a3.c>a5;){l.u();++l.e
f=j.$1(k)
q=a3.c
if(q>f){e=(q-f)/p
a4.$3(f,e,B.l)
if(g)a3.e+=e}i.$0()
q=a3.c
if(q<=a5)break
if(q>k)continue
d=m.aj(q)
d=j.$1(d<a5?a5:d)
c=o.br(d,a3.w)
q=a3.y
b=q==null?null:q.d
if(b==null)b=h
e=Math.floor(a3.d)+b-a3.d
while(e<=0){l.u();++l.e
e+=b}q=a3.a
a=a3.x
a0=a3.c
a1=r.B(a,e,a0,q,n,a0)
while(s.Y(a1,c,n).b>d){l.u();++l.e
e+=b
q=a3.x
a=a3.c
a1=r.B(q,b,a,a1,n,a)}a4.$3(a3.c,e,B.k)
k=d
g=!0}},
$S:27}
A.aa.prototype={
K(){return"RangeVariant."+this.b}}
A.dr.prototype={
b5(a,b,c){var s,r,q,p,o,n,m,l,k=this
for(s=k.a,r=k.b,q=k.c,p=A.m(["first",s,"last",r,"step",q],t.N,t.i),p=new A.C(p,p.$ti.i("C<1,2>")).gn(0);p.l();){o=p.d
n=o.b
m=o.a
if(isFinite(n))n=n<0
else n=!0
if(n)A.j(A.o(B.a,m+" must be finite and nonnegative.",0))}if(q===0||r<s)throw A.a(B.au)
l=(r-s)/q
A.c(l,"range interval count",!0)
if(l>9999||Math.abs(l-B.i.aV(l))>1e-8)throw A.a(B.az)
s=B.i.aV(l)
k.d!==$&&A.kP()
k.d=s+1},
gm(a){var s=this.d
s===$&&A.r()
return s},
aD(a){var s=this,r=s.d
r===$&&A.r()
if(a>=r)throw A.a(A.aK(a,0,s.gm(0)-1,"index",null))
return a===r-1?s.b:s.a+a*s.c}}
A.cf.prototype={}
A.eP.prototype={
$1(a){var s
switch(this.a.a){case 0:s=!0
break
case 1:s=a.b.b===B.f
break
case 2:s=!1
break
default:s=null}return s},
$S:15}
A.cc.prototype={}
A.f4.prototype={
$1(a){var s=this
return A.fm(16,new A.f5(s.a,a,s.b,s.c,s.d),t.i)},
$S:19}
A.f5.prototype={
$1(a){var s,r,q=this,p=q.b[a],o=q.a.a,n=q.c,m=(o.a[a]+o.b[a]+n.x-q.d.a)*1e5
o=n.d
n=n.e
s=2*o*(n-o)
if(m>s/(p*n))return p+(p-s/(m*n))*q.e
r=m/(2*(o-n))+1/p
if(r<=0)throw A.a(B.at)
return p+(1/r-p)*q.e},
$S:3}
A.eS.prototype={
$3(a,b,c){return A.fm(16,new A.eT(this.a,b,a,this.b,c),t.i)},
$S:30}
A.eT.prototype={
$1(a){var s,r,q,p=this,o=p.a.CW[a]
if(o<=p.b[a])return p.c[a]
s=p.d
r=s.e
s=s.d
q=o*1e5*r-s*p.e[a]*1e5
if(q<=0)throw A.a(B.aB)
o=p.c[a]
return o+(o-2*s*(r-s)/q)},
$S:3}
A.f6.prototype={
$2(a,b){var s,r,q,p=J.b0(16,t.i)
for(s=this.a,r=0;r<16;++r){q=a[r]
p[r]=q+(b[r]-q)*s}return p},
$S:10}
A.cF.prototype={}
A.e_.prototype={}
A.eu.prototype={
gaS(){var s=this,r=s.d
return r===$?s.d=new A.cn(s.a.d.b,s.c,s.b):r},
ga0(){var s=this,r=s.e
return r===$?s.e=new A.cm(s.a.d.b,s.c,s.b):r},
ac(a9,b0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8=this
a8.b.u()
s=A.j9()
r=a9==null
if(r){q=a8.a
p=q.d
o=A.i_(p,q.f)
n=o.a
a8.f=n
m=p.b
l=A.i2(o.b,q.e,a8.c,m,n)
n=l.a
a8.r=n
a8.w=l.b
k=l.c
q=k!=null
if(q&&k.a!==m.a)throw A.a(B.aw)
p=a8.x=A.hm(p.Q,m,a8.f,n)
if(q){q=k.b
n=k.c
m=k.d
q=a8.x=p.bJ(k.e,m,n,q)}else q=p
s.saM(new A.U(a8.r,a8.w,q))}else{s.saM(a9.c)
a8.f=a9.d
a8.r=a9.gO().a
a8.w=a9.gO().b
q=a9.gO().c
q.toString
a8.x=q
q=a9.e
B.b.N(a8.z,q)
if(q.length===0)p=0
else{p=B.b.gA(q)
p=p.c+p.a.c}a8.as=p
a8.Q=B.b.gA(q).a.b
a8.at=a9.r
a8.ax=a9.w
a8.ay=a9.f}q=a8.a
p=q.b
a8.y=B.b.gaN(p).c
r=r?p:B.J
p=r.length
n=q.d
m=n.r
j=n.w
i=n.y
h=n.z
g=h<0
f=h!==0
e=isFinite(h)
d=0
for(;d<p;++d){c=r[d]
b=c.a
a=a8.Q
if(b<a){a8.ao(b)
a8.y=c.c
b=a8.Q
a=c.b+Math.ceil(a8.as)-a8.as
a0=a8.y
a1=new A.aJ(b,b,a,a0)
a1.al(a0,a,b,b)
a8.a3(a1,B.p)}else{a2=b>a
if(a2){a=a8.x
a===$&&A.r()
a8.x=a.aI(0)}a=a2&&c.c.b===B.f
a3=c.c
if(a){a=a3.a
a4=new A.a8(a,B.f,h)
if(e)a0=g
else a0=!0
if(a0)A.j(A.o(B.a,u.o,0))
if(f){a0=a.b
a0=1-(a.a+a0)+a0===0
a=a0}else a=!0
if(a)A.j(B.r)}else a4=a3
for(b=A.i0(j,m,i,c.b,a3,a4,a8.Q,b),a=b.length,a5=0;a5<a;++a5){a6=b[a5]
a8.a3(a6,a6.a!==a6.b?B.L:B.p)}a8.y=a3}}r=!b0
if(r)a8.ao(0)
if(r){p=a8.x
p===$&&A.r()
a8.x=A.kx(p,n.b)}if(r&&a8.z.length!==0){r=a8.z
a7=r.pop()
p=a7.a
n=a7.b
m=a7.c
j=a8.r
j===$&&A.r()
i=a8.w
i===$&&A.r()
h=a8.x
h===$&&A.r()
r.push(A.ft(new A.U(j,i,h),n,p,m))}r=a8.f
r===$&&A.r()
p=s.b
if(p===s)A.j(new A.ag("Local '' has not been initialized."))
n=a8.ay
return A.ff(a8.at,a8.ax,q.a,n,p,"deco-core-calculation-v1-dev",r,a8.z)},
aF(){return this.ac(null,!1)},
bv(a){return this.ac(null,a)},
bu(a){return this.ac(a,!1)},
a3(a,b){var s,r,q,p,o,n=this,m=a.c
if(m===0)return
n.b.L()
s=a.b
if(s>a.a){r=n.gaS()
q=n.x
q===$&&A.r()
p=n.r
p===$&&A.r()
o=n.f
o===$&&A.r()
n.x=r.aK(q,p,o,a)}r=n.r
r===$&&A.r()
q=n.f
q===$&&A.r()
n.r=a.Z(r,n.c,q)
q=n.w
q===$&&A.r()
q=A.fo(q,a,n.f)
n.w=q
r=n.as
p=n.r
o=n.x
o===$&&A.r()
n.z.push(A.ft(new A.U(p,q,o),b,a,r))
n.as+=m
n.Q=s
n.y=a.d},
bp(){var s,r,q,p,o,n,m,l,k,j,i,h=this,g=h.a.d.w,f=h.Q/g
if(f===0)return 0
s=new A.ez(h)
r=s.$1(f)
for(q=h.b,p=0,o=0;o<16;++o){q.u();++q.e
n=new A.eB(h,o)
m=h.r
m===$&&A.r()
m=n.$1(m)
l=h.f
l===$&&A.r()
k=h.Q
if(isFinite(k))j=k<0
else j=!0
if(j)A.j(A.o(B.a,u.m,0))
i=l.a+k*l.c
if(!isFinite(i))A.j(A.o(B.a,"ambientBar must be finite.",0))
if(m>=i)return k
if(n.$1(r)<=h.f.a)continue
m=A.f9(q,new A.eA(h,n,s),0,1e-13,1e-12,f)
p=Math.max(p,h.Q-m.a*g)}return p},
ao(a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5=this
if(a6>=a5.Q)return
s=a5.gaS()
r=a5.x
r===$&&A.r()
a5.x=s.c6(r,a5.as)
r=a5.r
r===$&&A.r()
q=a5.Q
p=a5.as
s=a5.y
s===$&&A.r()
o=a5.bp()
n=a5.Q
m=a5.a.d
l=m.w
k=(n-o)/l
j=a5.r
i=a5.f
i===$&&A.r()
h=a5.c.B(a5.y,k,o,j,i,n)
g=A.a4(16,0,!1,t.i)
n=a5.x
i=a5.as
a5.x=n.bC(r,0,0,h,i+k,g,i,a5.z.length,g,g)
for(n=m.b.y,j=p+k,m=m.e,i=m.a,f=a5.b;e=0,!0;){f.u();++f.e
d=a5.x
a5.x=d.by(d.p2+1)
d=a5.ga0()
c=d.aG(a5.x,h,a5.f)
b=m.aE(c<=0?0:A.hH(c/i+0.5)*i)
b=d.c5(l,s,a5.x,b,o,m,h,a5.f)
a=a5.x
a=a.aI(Math.max(a.k2,b))
a5.x=a
if(b===0)break
a0=a5.av(b,o,h,s,a,!1,j,0)
a=d.c4(a0.c,a0.d-j,a5.f,a0.b)
a5.x=a
if(!n||d.c_(a)){e=b
break}a5.x=d.c8(a5.x).bF(0,a5.x.cy)}n=a5.ay
m=a5.x
a5.ay=Math.max(n,m.k2)
a1=a5.av(e,q,r,s,m,!0,p,a6)
for(s=a1.a,r=s.length,a2=!1,a3=0;a3<s.length;s.length===r||(0,A.cK)(s),++a3){a4=s[a3]
n=a4.b
if(n===B.k)a2=!0
m=a4.a
l=m.c
a5.at=a5.at+l
if(a2)a5.ax+=l
a5.x=a4.d
a5.a3(m,n)}a5.r=a1.b
a5.x=a1.c},
av(a4,a5,a6,a7,a8,a9,b0,b1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=this,a3={}
a3.a=a6
a3.b=a8
a3.c=a5
a3.d=b0
a3.e=a7
a3.f=null
s=A.k([],t.U)
r=new A.ey(a3,a2,new A.ex())
q=new A.ew(a3,a2,a9,s)
p=Math.max(b1,a4)
for(o=a2.b,n=a2.c,m=t.i,l=a2.a.d,k=l.e,j=l.w,i=l.x;a3.c>b1;){o.u();++o.e
l=a3.c
if(l>p)q.$3(p,(l-p)/j,B.l)
r.$0()
l=a3.c
if(l<=b1)break
if(l>p)continue
h=Math.max(b1,k.aj(l))
l=a2.ga0()
g=a3.b
f=a2.f
f===$&&A.r()
a3.b=l.bt(g,h,f)
f=a2.f
g=a3.c
if(isFinite(g))e=g<0
else e=!0
if(e)A.j(A.o(B.a,u.m,0))
d=f.a+g*f.c
if(!isFinite(d))A.j(A.o(B.a,"ambientBar must be finite.",0))
c=A.fL(d,f.b,a3.e)
g=A.a4(16,c.b,!1,m)
f=A.a4(16,c.a,!1,m)
g=A.l(g,"nitrogenBar",!1)
f=A.l(f,"heliumBar",!1)
if(l.ae(a3.b,new A.N(g,f),a2.f,!0)>h)throw A.a(A.o(B.j,"Off-gassing gradient cannot clear the next stop from "+A.u(a3.c)+"m.",0))
g=a3.f
b=g==null?null:g.d
if(b==null)b=i
a=A.hH(a3.d/b+0.501)*b-a3.d
if(a<=0)a=b
g=a3.a
f=a2.f
e=a3.e
a0=a3.c
a1=n.B(e,a,a0,g,f,a0)
while(l.ae(a3.b,a1,a2.f,!0)>h){o.u();++o.e
a+=b
g=a2.f
f=a3.e
e=a3.c
a1=n.B(f,b,e,a1,g,e)}q.$3(a3.c,a,B.k)
p=h}return new A.e_(s,a3.a,a3.b,a3.d)}}
A.ez.prototype={
$1(a){var s,r,q,p=this.a,o=p.r
o===$&&A.r()
s=p.f
s===$&&A.r()
r=p.y
r===$&&A.r()
q=p.Q
return p.c.B(r,a,Math.max(0,q-a*p.a.d.w),o,s,q)},
$S:8}
A.eB.prototype={
$1(a){var s=this.b
return a.a[s]+a.b[s]+this.a.a.d.b.x},
$S:33}
A.eA.prototype={
$1(a){var s=this.b.$1(this.c.$1(a)),r=this.a,q=r.f
q===$&&A.r()
return s-q.D(Math.max(0,r.Q-a*r.a.d.w))},
$S:1}
A.ex.prototype={
$2(a,b){return Math.abs(a-b)<=3552713678800501e-30*Math.max(1,Math.max(Math.abs(a),Math.abs(b)))},
$S:5}
A.ey.prototype={
$0(){var s,r,q,p,o,n,m,l,k
for(s=this.b.a.c,r=s.length,q=this.a,p=this.c,o=0;o<r;++o){n=s[o]
m=!1
if(!n.c){l=n.a
k=q.c
if(l>=k||p.$2(l,k)){m=q.f
m=m==null||l<m.a}}if(m){q.e=n.b
q.f=n}}},
$S:0}
A.ew.prototype={
$3(a,b,c){var s,r,q,p,o,n=this
if(b===0)return
s=n.b
s.b.L()
r=n.a
q=r.c
p=A.dq(r.e,b,a,q)
r.b=r.b.bA(r.a)
q=r.a
o=s.f
o===$&&A.r()
r.a=p.Z(q,s.c,o)
if(n.c&&c===B.l)r.b=s.ga0().aT(r.b,r.a,s.f.D(a))
n.d.push(new A.cF(p,c,r.b))
r.c=a
r.d+=b},
$S:13}
A.aJ.prototype={
al(a,b,c,d){var s,r,q=this.a
A.c(q,"startDepthMetres",!0)
s=this.b
A.c(s,"endDepthMetres",!0)
r=this.c
A.c(r,"durationMin",!0)
if(r===0&&q!==s)throw A.a(B.u)},
Z(a,b,c){var s=this
return b.B(s.d,s.c,s.b,a,c,s.a)}}
A.N.prototype={
k(){return A.m(["nitrogenBar",this.a,"heliumBar",this.b],t.N,t.K)}}
A.dC.prototype={
$1(a){return A.y(a,"nitrogenBar")},
$S:2}
A.dD.prototype={
$1(a){return A.y(a,"heliumBar")},
$S:2}
A.dy.prototype={
B(a,b,c,d,e,f){var s,r,q,p,o,n
A.c(b,"durationMin",!0)
s=e.D(f)
r=e.D(c)
if(b===0){if(f!==c)throw A.a(B.u)
return d}q=new A.dz(this,e,a)
p=a.c
if(p!=null&&s!==r){o=p+e.b
n=(o-s)/(r-s)
if(n>0&&n<1)return q.$4(q.$4(d,s,o,b*n),o,r,b*(1-n))}return q.$4(d,s,r,b)}}
A.dz.prototype={
$4(a,b,c,d){var s,r=this.b.b,q=this.c,p=A.fL(b,r,q),o=A.fL(c,r,q)
q=new A.dA(d)
r=this.a
s=q.$4(a.a,r.a,p.b,o.b)
r=q.$4(a.b,r.b,p.a,o.a)
return new A.N(A.l(s,"nitrogenBar",!1),A.l(r,"heliumBar",!1))},
$S:34}
A.dA.prototype={
$4(a,b,c,d){var s,r,q,p=J.b0(16,t.i)
for(s=this.a,r=(d-c)/s,q=0;q<16;++q)p[q]=A.i3(s,a[q],r,c,0.6931471805599453/b[q])
return p},
$S:35}
A.dm.prototype={
D(a){var s
A.c(a,"depthMetres",!0)
s=this.a+a*this.c
A.c(s,"ambientBar",!1)
return s},
aL(a){var s
A.c(a,"ambientBar",!0)
s=(a-this.a)/this.c
A.c(s,"depthMetres",!1)
return s}}
A.du.prototype={
aE(a){var s,r
A.c(a,"ceilingMetres",!1)
if(a<=0)return 0
s=this.b
if(a<=s)return s
r=this.a
return s+B.i.bw((a-s)/r)*r},
aj(a){var s,r
A.c(a,"depthMetres",!0)
s=this.b
if(a<=s)return 0
r=a-this.a
return r<s?s:r}}
A.cm.prototype={
ae(a,b,c,d){var s,r,q,p,o,n,m,l,k,j=d?a.ay:a.at,i=d?a.ch:a.ax
for(s=this.a.x,r=b.a,q=b.b,p=0,o=0;o<16;++o){n=r[o]
m=q[o]
l=n+m
k=l===0?Math.min(j[o],i[o]):(j[o]*n+i[o]*m)/l
p=Math.max(p,Math.max(0,l+s-k))}return Math.max(0,c.aL(p))},
aG(a,b,c){return this.ae(a,b,c,!1)},
bt(a,b,c){var s,r,q=c.D(a.k2)*1e5,p=c.D(b)*1e5
if(p>q)throw A.a(B.ay)
s=new A.dH(this,q,p)
r=s.$1(a.at)
return a.bE(s.$1(a.ax),r)},
c4(a,b,c,d){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
A.c(b,"decoDurationMin",!0)
s=(c.a-c.b)*0.79
r=A.k([],t.n)
for(q=this.c,p=d.a,o=d.b,n=this.b,m=n.a,n=n.b,l=0;l<16;++l){q.u();++q.e
k=p[l]-s
j=o[l]
i=0.6931471805599453/m[l]
h=0.6931471805599453/n[l]
if(k>0)g=(j/h+k/i)/(j+k)
else if(k===0&&j>0)g=1/h
else{f=j+k
if(f>0){e=Math.log(-k/j)/(i-h)
g=(j/h*(1-Math.exp(-h*e))+k/i*(1-Math.exp(-i*e)))/f}else g=0}if(isFinite(g))f=g<0
else f=!0
if(f)A.j(A.o(B.a,"surface phase volume must be finite and nonnegative.",0))
r.push(g)}return a.bI(b,r,new A.E(r,new A.dL(b),t.d))},
c_(a){var s,r=J.b0(16,t.S)
for(s=0;s<16;++s)r[s]=s
return B.b.aC(r,new A.dK(a))},
c8(a){var s=new A.dM(this,a),r=s.$2(a.Q,a.y)
return a.bD(s.$2(a.as,a.z),r)},
aT(a,b,c){var s,r,q,p,o,n
A.c(c,"ambientBar",!0)
s=J.b0(16,t.i)
for(r=a.CW,q=b.a,p=b.b,o=this.a.x,n=0;n<16;++n)s[n]=Math.max(r[n],q[n]+p[n]+o-c)
return a.bz(s)},
c5(a,b,c,d,e,f,g,h){var s,r,q,p,o
A.c(e,"fromMetres",!0)
A.c(d,"candidateMetres",!0)
A.c(a,"ascentMetresPerMin",!0)
if(a===0)throw A.a(B.D)
for(s=f.a,r=this.c,q=this.b,p=f.b,o=d;o<=e;){r.u();++r.e
if(this.aG(c,q.B(b,(e-o)/a,o,g,h,e),h)<=o)return o
o=o===0?p:o+s}throw A.a(B.a6)}}
A.dH.prototype={
$1(a){var s=A.R(a).i("E<1,b>")
s=A.W(new A.E(a,new A.dJ(this.a,this.b,this.c),s),s.i("H.E"))
return s},
$S:19}
A.dJ.prototype={
$1(a){var s,r,q,p,o=this.a.c
o.L()
if(a<=0)throw A.a(B.ah)
s=this.b
r=this.c
if(s===r)return a
q=a*1e5
p=s+q
return a/A.f9(o,new A.dI(r/p,q/p),1,1e-13,1e-12,Math.pow(s/r,0.3333333333333333)).a},
$S:1}
A.dI.prototype={
$1(a){return this.a*a*a*a+this.b*a*a-1},
$S:1}
A.dL.prototype={
$1(a){return a+this.a},
$S:1}
A.dK.prototype={
$1(a){var s=this.a
return Math.abs(s.cy[a]-s.db[a])<=1},
$S:36}
A.dM.prototype={
$2(a,b){return A.fm(16,new A.dN(this.a,this.b,a,b),t.i)},
$S:10}
A.dN.prototype={
$1(a){var s,r,q,p,o,n,m=this,l=m.a
l.c.L()
s=m.b.cy[a]
if(s<=0)throw A.a(B.aA)
l=l.a
r=l.r
q=l.d
l=l.e
p=m.c[a]*1e5+r*q/(l*s)
o=p*p-4*(q*q*r*m.d[a]*1e5/(l*l*s))
if(o<0)throw A.a(B.a7)
n=(p+Math.sqrt(o))/2/1e5
A.c(n,"relaxed gradient",!0)
return n},
$S:3}
A.cn.prototype={
aK(a9,b0,b1,b2){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=this,a7=b2.b,a8=b2.a
if(a7<a8)throw A.a(B.aF)
if(a8===a7)return a9
s=b2.Z(b0,a6.b,b1)
r=b1.D(a8)
q=b1.D(a7)
a7=a6.a
p=a7.f
o=p*1e5
a8=t.i
n=A.W(a9.f,a8)
m=A.W(a9.r,a8)
l=A.W(a9.dx,a8)
k=A.W(a9.dy,a8)
j=a7.e-a7.d
for(a8=a9.d,i=a9.e,h=a6.c,g=b0.a,f=b0.b,a7=a7.x,e=s.a,d=s.b,c=b2.c,b=q-r,a=0;a<16;++a){h.u();++h.e
a0=g[a]+f[a]+a7
a1=q-(e[a]+d[a]+a7)
if(a1<=p){n[a]=Math.max(n[a],a1)
m[a]=Math.max(m[a],a1)
continue}a2=r-a0
if(a2===p){l[a]=r
k[a]=a0}else if(a2<p){a3=new A.dQ(a6,b0,b1,b2)
a4=A.f9(h,new A.dR(a6,a3,r,q,b2,a,p),0,1e-12,1e-10,c).a
a5=a3.$1(a4)
l[a]=r+b*a4/c
k[a]=a5.a[a]+a5.b[a]+a7}if(l[a]<=0||k[a]<=0)throw A.a(B.aE)
a3=new A.dS(a6,o,j,q,l,a,k)
n[a]=Math.max(n[a],A.hS(a3.$1(a8[a])))
m[a]=Math.max(m[a],A.hS(a3.$1(i[a])))}return a9.bK(l,m,n,b0,k)},
c6(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d
A.c(b,"diveTimeMin",!0)
s=Math.exp(-b/this.a.w)
r=t.n
q=A.k([],r)
p=A.k([],r)
o=A.k([],r)
n=A.k([],r)
m=A.k([],r)
l=A.k([],r)
k=new A.dU(this,s)
for(r=this.c,j=a.d,i=a.f,h=a.e,g=a.r,f=0;f<16;++f){r.u();++r.e
e=k.$2(j[f],i[f])
d=k.$2(h[f],g[f])
q.push(e.c)
p.push(d.c)
o.push(e.a)
n.push(d.a)
m.push(e.b)
l.push(d.b)}r=t.i
j=A.a4(16,0,!1,r)
return a.bB(n,o,l,m,A.a4(16,0,!1,r),j,l,m,p,q)}}
A.dQ.prototype={
$1(a){var s=this,r=s.d,q=r.a
return s.a.b.B(r.d,a,q+(r.b-q)*a/r.c,s.b,s.c,q)},
$S:8}
A.dR.prototype={
$1(a){var s=this,r=s.b.$1(a),q=s.c,p=s.f
return q+(s.d-q)*a/s.e.c-r.a[p]-r.b[p]-s.a.a.x-s.r},
$S:1}
A.dS.prototype={
$1(a){var s=this,r=s.b,q=2*s.c,p=1/(r/q+1/a),o=s.f,n=(s.d-s.e[o])*1e5,m=s.r[o]*1e5,l=n+m+q/p,k=q/(l*p),j=A.f9(s.a.c,new A.dT(k,m/l),k,1e-13,1e-12,1).a,i=(r+n+m*(1-1/(j*j*j)))/1e5
A.c(i,"impermeable crushing pressure",!0)
return i},
$S:1}
A.dT.prototype={
$1(a){return a*a*a-this.a*a*a-this.b},
$S:1}
A.dU.prototype={
$2(a,b){var s,r,q,p,o
if(b===0)s=a
else{r=this.a.a
s=1/(b*1e5/(2*(r.e-r.d))+1/a)}r=this.b
q=a+(s-a)*r
p=this.a.a
o=p.d
p=p.e
return new A.cC(b*(s/q)*r,2*o*(p-o)/(q*p)/1e5,q)},
$S:37}
A.dZ.prototype={
K(){return"WorkerFailureKind."+this.b}}
A.cp.prototype={
j(a){return"WorkerFailure(protocol): Calculation worker version is incompatible."}}
A.cV.prototype={
k(){return A.m(["requestId",this.a,"inputRevision",this.b,"dependencyVersion",this.c,"modelVersion","deco-core-calculation-v1-dev","protocolVersion",2],t.N,t.X)},
c0(a){var s=this.k()
return new A.C(s,A.Y(s).i("C<1,2>")).bR(0,new A.cW(a))}}
A.cW.prototype={
$1(a){return J.a0(this.a.h(0,a.a),a.b)},
$S:38}
A.f7.prototype={
$1(a){var s=A.ha(this.b,t.N,t.X)
s.N(0,a)
return this.a.$1(s)},
$S:7}
A.ch.prototype={
k(){var s,r=this,q=r.a.k(),p=r.b
p=p==null?null:p.k()
s=r.y
s=s==null?null:s.k()
return A.m(["request",q,"bailout",p,"depthMetres",r.c,"durationMin",r.d,"variant",r.e.b,"runtimeMin",r.f,"ascentMin",r.r,"decompressionMin",r.w,"firstStopMetres",r.x,"failure",s],t.N,t.X)}}
A.f1.prototype={
$1(a){var s,r,q,p,o,n,m,l,k=t.f,j=k.a(B.z.bM(a.data,null))
switch(j.h(0,"operation")){case"calculation":A.kM(j,A.kK())
break
case"range":s=k.a(j.h(0,"identity"))
r=new A.cV(A.cG(s.h(0,"requestId")),A.cG(s.h(0,"inputRevision")),A.eE(s.h(0,"dependencyVersion")))
if(!r.c0(s)){A.fD(A.m(["identity",r.k()],t.N,t.X))
return}q=t.w.a(j.h(0,"bailout"))
p=A.h2(k.a(j.h(0,"source")))
o=q==null?null:A.fT(q)
n=A.hB(k.a(j.h(0,"depths")))
k=A.hB(k.a(j.h(0,"durations")))
m=J.aA(t.W.a(j.h(0,"variants")),new A.eZ(),t.D)
m=A.W(m,m.$ti.i("H.E"))
A.f8(o,n,k,s,new A.f_(),p,m,new A.f0(this.a))
break
case"rangeAck":k=this.a
l=k.a
k.a=null
if(l!=null)l.ah(!0)
break}},
$S:40}
A.eZ.prototype={
$1(a){return A.iw(B.aR,A.eE(a))},
$S:41}
A.f_.prototype={
$1(a){var s,r=A.ha(a,t.N,t.X),q=a.h(0,"cell")
if(q instanceof A.ch)r.M(0,"cell",q.k())
s=a.h(0,"failure")
if(s instanceof A.e)r.M(0,"failure",s.k())
return A.fD(r)},
$S:7}
A.f0.prototype={
$0(){var s=new A.F($.x,t.k)
this.a.a=new A.bm(s,t.a)
return s},
$S:42};(function aliases(){var s=J.ah.prototype
s.b0=s.j})();(function installTearOffs(){var s=hunkHelpers._static_0,r=hunkHelpers._static_1
s(A,"k6","iS",16)
r(A,"ko","j6",4)
r(A,"kp","j7",4)
r(A,"kq","j8",4)
s(A,"hM","kh",0)
r(A,"kt","jK",12)
r(A,"kK","fD",7)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.h,null)
q(A.h,[A.fj,J.bT,A.be,J.aB,A.G,A.bM,A.I,A.ap,A.t,A.ds,A.aF,A.co,A.b_,A.bt,A.dE,A.di,A.aZ,A.bx,A.dg,A.c_,A.bZ,A.e4,A.X,A.cu,A.er,A.ep,A.cq,A.by,A.S,A.cs,A.aN,A.F,A.cr,A.cD,A.eC,A.aL,A.el,A.cx,A.v,A.bN,A.bP,A.ej,A.aD,A.e5,A.c9,A.bf,A.e6,A.d8,A.ai,A.J,A.cE,A.dv,A.bh,A.da,A.d1,A.cT,A.cR,A.cM,A.U,A.d9,A.a8,A.bL,A.cZ,A.a3,A.V,A.bQ,A.a5,A.cX,A.dO,A.dV,A.e,A.cU,A.bd,A.ca,A.cN,A.dr,A.cf,A.cc,A.cF,A.e_,A.eu,A.aJ,A.N,A.dy,A.dm,A.du,A.cm,A.cn,A.cp,A.cV,A.ch])
q(J.bT,[J.bV,J.b2,J.b5,J.b4,J.b6,J.b3,J.aE])
q(J.b5,[J.ah,J.q,A.aG,A.ba])
q(J.ah,[J.cb,J.bj,J.af])
r(J.bU,A.be)
r(J.db,J.q)
q(J.b3,[J.b1,J.bW])
q(A.G,[A.aM,A.i,A.bl,A.aP])
r(A.an,A.aM)
r(A.bn,A.an)
q(A.I,[A.ao,A.a9,A.cv])
q(A.ap,[A.d3,A.d2,A.dx,A.eV,A.eX,A.e1,A.e0,A.eF,A.ef,A.cP,A.cQ,A.cO,A.d_,A.d6,A.d7,A.d4,A.d5,A.cY,A.dP,A.dX,A.dY,A.dW,A.fa,A.dj,A.eH,A.eJ,A.eI,A.eP,A.f4,A.f5,A.eS,A.eT,A.ez,A.eB,A.eA,A.ew,A.dC,A.dD,A.dz,A.dA,A.dH,A.dJ,A.dI,A.dL,A.dK,A.dN,A.dQ,A.dR,A.dS,A.dT,A.cW,A.f7,A.f1,A.eZ,A.f_])
q(A.d3,[A.d0,A.dc,A.eW,A.eG,A.eO,A.eg,A.dh,A.ek,A.fb,A.f3,A.eK,A.f6,A.ex,A.dM,A.dU])
q(A.t,[A.ag,A.ac,A.bX,A.ck,A.ci,A.ct,A.b7,A.bJ,A.a7,A.bk,A.cj,A.bg,A.bO])
q(A.i,[A.H,A.aq,A.C])
q(A.H,[A.bi,A.E,A.cw])
q(A.bt,[A.cy,A.cz,A.cA])
q(A.cy,[A.cB,A.bu,A.bv])
r(A.cC,A.cz)
r(A.a6,A.cA)
q(A.d2,[A.dn,A.e2,A.e3,A.eq,A.e7,A.eb,A.ea,A.e9,A.e8,A.ee,A.ed,A.ec,A.eo,A.eN,A.eL,A.ey,A.f0])
r(A.bc,A.ac)
q(A.dx,[A.dt,A.aX])
q(A.ba,[A.c0,A.aH])
q(A.aH,[A.bp,A.br])
r(A.bq,A.bp)
r(A.b8,A.bq)
r(A.bs,A.br)
r(A.b9,A.bs)
q(A.b8,[A.c1,A.c2])
q(A.b9,[A.c3,A.c4,A.c5,A.c6,A.c7,A.bb,A.c8])
r(A.bz,A.ct)
r(A.bm,A.cs)
r(A.en,A.eC)
r(A.bw,A.aL)
r(A.bo,A.bw)
r(A.bY,A.b7)
r(A.dd,A.bN)
q(A.bP,[A.df,A.de])
r(A.ei,A.ej)
q(A.a7,[A.cg,A.bS])
q(A.e5,[A.aY,A.aC,A.aj,A.T,A.aa,A.dZ])
s(A.bp,A.v)
s(A.bq,A.b_)
s(A.br,A.v)
s(A.bs,A.b_)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{d:"int",b:"double",hW:"num",n:"String",L:"bool",J:"Null",f:"List",h:"Object",D:"Map",w:"JSObject"},mangledNames:{},types:["~()","b(b)","b(h?)","b(d)","~(~())","L(b,b)","b(n)","~(D<n,h?>)","N(b)","J(@)","f<b>(f<b>,f<b>)","J()","@(@)","~(b,b,aj)","~(h?,h?)","L(V)","d()","V(h?)","D<n,h?>(V)","f<b>(f<b>)","G<b>(n)","a3(h?)","D<n,h?>(a3)","J(h,ak)","L(+high,intercept,low,slope(b,b,b,b))","b(b,a5)","~(d,@)","~(b)","J(@,ak)","~(@)","f<b>(f<b>,f<b>,f<b>)","J(~())","@(n)","b(N)","N(N,b,b,b)","f<b>(f<b>,f<b>,b,b)","L(d)","+crush,gradient,radius(b,b,b)(b,b)","L(ai<n,h?>)","@(@,n)","J(w)","aa(h?)","ae<L>()","D<n,h?>(a5)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.cB&&a.b(c.a)&&b.b(c.b),"2;a,b":(a,b)=>c=>c instanceof A.bu&&a.b(c.a)&&b.b(c.b),"2;helium,nitrogen":(a,b)=>c=>c instanceof A.bv&&a.b(c.a)&&b.b(c.b),"3;crush,gradient,radius":(a,b,c)=>d=>d instanceof A.cC&&a.b(d.a)&&b.b(d.b)&&c.b(d.c),"4;high,intercept,low,slope":a=>b=>b instanceof A.a6&&A.kJ(a,b.a)}}
A.jq(v.typeUniverse,JSON.parse('{"cb":"ah","bj":"ah","af":"ah","kW":"aG","bV":{"L":[],"p":[]},"b2":{"p":[]},"b5":{"w":[]},"ah":{"w":[]},"q":{"f":["1"],"i":["1"],"w":[]},"bU":{"be":[]},"db":{"q":["1"],"f":["1"],"i":["1"],"w":[]},"b3":{"b":[]},"b1":{"b":[],"d":[],"p":[]},"bW":{"b":[],"p":[]},"aE":{"n":[],"p":[]},"aM":{"G":["2"]},"an":{"aM":["1","2"],"G":["2"]},"bn":{"an":["1","2"],"aM":["1","2"],"i":["2"],"G":["2"]},"ao":{"I":["3","4"],"D":["3","4"],"I.V":"4","I.K":"3"},"ag":{"t":[]},"i":{"G":["1"]},"H":{"i":["1"],"G":["1"]},"bi":{"H":["1"],"i":["1"],"G":["1"],"H.E":"1"},"E":{"H":["2"],"i":["2"],"G":["2"],"H.E":"2"},"bl":{"G":["1"]},"bc":{"ac":[],"t":[]},"bX":{"t":[]},"ck":{"t":[]},"bx":{"ak":[]},"ci":{"t":[]},"a9":{"I":["1","2"],"D":["1","2"],"I.V":"2","I.K":"1"},"aq":{"i":["1"],"G":["1"]},"C":{"i":["ai<1,2>"],"G":["ai<1,2>"]},"aG":{"w":[],"p":[]},"ba":{"w":[]},"c0":{"w":[],"p":[]},"aH":{"O":["1"],"w":[]},"b8":{"v":["b"],"f":["b"],"O":["b"],"i":["b"],"w":[]},"b9":{"v":["d"],"f":["d"],"O":["d"],"i":["d"],"w":[]},"c1":{"v":["b"],"f":["b"],"O":["b"],"i":["b"],"w":[],"p":[],"v.E":"b"},"c2":{"v":["b"],"f":["b"],"O":["b"],"i":["b"],"w":[],"p":[],"v.E":"b"},"c3":{"v":["d"],"f":["d"],"O":["d"],"i":["d"],"w":[],"p":[],"v.E":"d"},"c4":{"v":["d"],"f":["d"],"O":["d"],"i":["d"],"w":[],"p":[],"v.E":"d"},"c5":{"v":["d"],"f":["d"],"O":["d"],"i":["d"],"w":[],"p":[],"v.E":"d"},"c6":{"v":["d"],"f":["d"],"O":["d"],"i":["d"],"w":[],"p":[],"v.E":"d"},"c7":{"v":["d"],"f":["d"],"O":["d"],"i":["d"],"w":[],"p":[],"v.E":"d"},"bb":{"v":["d"],"f":["d"],"O":["d"],"i":["d"],"w":[],"p":[],"v.E":"d"},"c8":{"v":["d"],"f":["d"],"O":["d"],"i":["d"],"w":[],"p":[],"v.E":"d"},"ct":{"t":[]},"bz":{"ac":[],"t":[]},"aP":{"G":["1"]},"S":{"t":[]},"bm":{"cs":["1"]},"F":{"ae":["1"]},"bo":{"aL":["1"],"i":["1"]},"I":{"D":["1","2"]},"aL":{"i":["1"]},"bw":{"aL":["1"],"i":["1"]},"cv":{"I":["n","@"],"D":["n","@"],"I.V":"@","I.K":"n"},"cw":{"H":["n"],"i":["n"],"G":["n"],"H.E":"n"},"b7":{"t":[]},"bY":{"t":[]},"f":{"i":["1"]},"bJ":{"t":[]},"ac":{"t":[]},"a7":{"t":[]},"cg":{"t":[]},"bS":{"t":[]},"bk":{"t":[]},"cj":{"t":[]},"bg":{"t":[]},"bO":{"t":[]},"c9":{"t":[]},"bf":{"t":[]},"cE":{"ak":[]},"iD":{"f":["d"],"i":["d"]},"j1":{"f":["d"],"i":["d"]},"j0":{"f":["d"],"i":["d"]},"iB":{"f":["d"],"i":["d"]},"iZ":{"f":["d"],"i":["d"]},"iC":{"f":["d"],"i":["d"]},"j_":{"f":["d"],"i":["d"]},"iz":{"f":["b"],"i":["b"]},"iA":{"f":["b"],"i":["b"]}}'))
A.jp(v.typeUniverse,JSON.parse('{"co":1,"b_":1,"c_":1,"aH":1,"by":1,"cD":1,"bw":1,"bN":2,"bP":2}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type",m:"depthMetres must be finite and nonnegative.",o:"setpointBar must be finite and nonnegative."}
var t=(function rtii(){var s=A.ax
return{A:s("bL"),O:s("i<@>"),C:s("t"),Y:s("kV"),J:s("V"),I:s("q<V>"),_:s("q<a3>"),Z:s("q<aa>"),G:s("q<a5>"),s:s("q<n>"),U:s("q<cF>"),n:s("q<b>"),b:s("q<@>"),T:s("b2"),m:s("w"),g:s("af"),p:s("O<@>"),L:s("a3"),j:s("f<@>"),W:s("f<h?>"),M:s("D<@,@>"),f:s("D<n,h?>"),d:s("E<b,b>"),P:s("J"),K:s("h"),q:s("aJ"),D:s("aa"),V:s("kX"),F:s("+()"),E:s("a5"),l:s("ak"),N:s("n"),R:s("p"),c:s("ac"),B:s("bj"),a:s("bm<L>"),k:s("F<L>"),e:s("F<@>"),h:s("aP<cf>"),y:s("L"),i:s("b"),z:s("@"),v:s("@(h)"),Q:s("@(h,ak)"),S:s("d"),r:s("ae<J>?"),t:s("w?"),w:s("D<n,h?>?"),X:s("h?"),x:s("n?"),u:s("L?"),dd:s("b?"),a3:s("d?"),ae:s("hW?"),H:s("hW"),o:s("~")}})();(function constants(){var s=hunkHelpers.makeConstList
B.aJ=J.bT.prototype
B.b=J.q.prototype
B.c=J.b1.prototype
B.i=J.b3.prototype
B.o=J.aE.prototype
B.aK=J.af.prototype
B.aL=J.b5.prototype
B.K=J.cb.prototype
B.w=J.bj.prototype
B.e=new A.aY(0,"oc")
B.f=new A.aY(1,"ccr")
B.x=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.M=function() {
  var toStringFunction = Object.prototype.toString;
  function getTag(o) {
    var s = toStringFunction.call(o);
    return s.substring(8, s.length - 1);
  }
  function getUnknownTag(object, tag) {
    if (/^HTML[A-Z].*Element$/.test(tag)) {
      var name = toStringFunction.call(object);
      if (name == "[object Object]") return null;
      return "HTMLElement";
    }
  }
  function getUnknownTagGenericBrowser(object, tag) {
    if (object instanceof HTMLElement) return "HTMLElement";
    return getUnknownTag(object, tag);
  }
  function prototypeForTag(tag) {
    if (typeof window == "undefined") return null;
    if (typeof window[tag] == "undefined") return null;
    var constructor = window[tag];
    if (typeof constructor != "function") return null;
    return constructor.prototype;
  }
  function discriminator(tag) { return null; }
  var isBrowser = typeof HTMLElement == "function";
  return {
    getTag: getTag,
    getUnknownTag: isBrowser ? getUnknownTagGenericBrowser : getUnknownTag,
    prototypeForTag: prototypeForTag,
    discriminator: discriminator };
}
B.R=function(getTagFallback) {
  return function(hooks) {
    if (typeof navigator != "object") return hooks;
    var userAgent = navigator.userAgent;
    if (typeof userAgent != "string") return hooks;
    if (userAgent.indexOf("DumpRenderTree") >= 0) return hooks;
    if (userAgent.indexOf("Chrome") >= 0) {
      function confirm(p) {
        return typeof window == "object" && window[p] && window[p].name == p;
      }
      if (confirm("Window") && confirm("HTMLElement")) return hooks;
    }
    hooks.getTag = getTagFallback;
  };
}
B.N=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.Q=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Firefox") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "GeoGeolocation": "Geolocation",
    "Location": "!Location",
    "WorkerMessageEvent": "MessageEvent",
    "XMLDocument": "!Document"};
  function getTagFirefox(o) {
    var tag = getTag(o);
    return quickMap[tag] || tag;
  }
  hooks.getTag = getTagFirefox;
}
B.P=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Trident/") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "HTMLDDElement": "HTMLElement",
    "HTMLDTElement": "HTMLElement",
    "HTMLPhraseElement": "HTMLElement",
    "Position": "Geoposition"
  };
  function getTagIE(o) {
    var tag = getTag(o);
    var newTag = quickMap[tag];
    if (newTag) return newTag;
    if (tag == "Object") {
      if (window.DataView && (o instanceof window.DataView)) return "DataView";
    }
    return tag;
  }
  function prototypeForTagIE(tag) {
    var constructor = window[tag];
    if (constructor == null) return null;
    return constructor.prototype;
  }
  hooks.getTag = getTagIE;
  hooks.prototypeForTag = prototypeForTagIE;
}
B.O=function(hooks) {
  var getTag = hooks.getTag;
  var prototypeForTag = hooks.prototypeForTag;
  function getTagFixed(o) {
    var tag = getTag(o);
    if (tag == "Document") {
      if (!!o.xmlVersion) return "!Document";
      return "!HTMLDocument";
    }
    return tag;
  }
  function prototypeForTagFixed(tag) {
    if (tag == "Document") return null;
    return prototypeForTag(tag);
  }
  hooks.getTag = getTagFixed;
  hooks.prototypeForTag = prototypeForTagFixed;
}
B.y=function(hooks) { return hooks; }

B.z=new A.dd()
B.S=new A.c9()
B.m=new A.ds()
B.bg=new A.dZ(4,"protocol")
B.T=new A.cp()
B.h=new A.en()
B.U=new A.cE()
B.a=new A.T(0,"invalidInput")
B.n=new A.T(1,"outsideModelDomain")
B.B=new A.T(4,"nonFinite")
B.q=new A.T(5,"budgetExceeded")
B.j=new A.T(6,"nonConvergence")
B.C=new A.T(7,"cancelled")
B.W=new A.e(B.a,"Skin compression must exceed surface tension.",0)
B.X=new A.e(B.a,"Ambient pressure below water vapour pressure.",0)
B.Y=new A.e(B.a,"A B\xfchlmann engine cannot execute a VPM request.",0)
B.Z=new A.e(B.a,"Travel rates, stop duration and low setpoint must be positive; VPM index0\u20134.",0)
B.a_=new A.e(B.a,"Range is empty or exceeds the requested cell limit.",0)
B.a0=new A.e(B.a,"Bailout must occur strictly inside the underwater profile.",0)
B.a1=new A.e(B.a,"Surface must exceed vapour pressure; hydrostatic gradient must be positive.",0)
B.a2=new A.e(B.a,"Invalid root search parameters.",0)
B.a3=new A.e(B.a,"Bailout requires a positive underwater depth.",0)
B.a4=new A.e(B.a,"Altitude travel requires positive travel time and a higher destination.",0)
B.a5=new A.e(B.a,"Range bailout must belong to its source.",0)
B.a6=new A.e(B.j,"Projected ascent has no admissible first stop.",0)
B.r=new A.e(B.a,"CCR needs a positive setpoint and inert diluent fraction.",0)
B.a7=new A.e(B.j,"Critical-volume equation has no real allowable gradient.",0)
B.a8=new A.e(B.a,"VPM conservatism must be0\u20134.",0)
B.a9=new A.e(B.a,"Result identity is required.",0)
B.aa=new A.e(B.a,"Gradient factor must be in (0,1].",0)
B.ab=new A.e(B.a,"Travel rates must be positive.",0)
B.ac=new A.e(B.a,"Result segments must be continuous in time and depth.",0)
B.ad=new A.e(B.a,"Gas fractions exceed one.",0)
B.ae=new A.e(B.a,"Invalid inspired pressure trajectory or rate constant.",0)
B.af=new A.e(B.a,"Bailout identity is required.",0)
B.ag=new A.e(B.n,"Oxygen exposure exceeds the published1.6ATA policy domain.",0)
B.ah=new A.e(B.a,"Boyle compensation needs positive allowable gradients.",0)
B.ai=new A.e(B.a,"Bailout switches must be OC.",0)
B.aj=new A.e(B.a,"Sea-level pressure must be positive.",0)
B.ak=new A.e(B.j,"No first-stop candidate at or below the current depth clears its ceiling.",0)
B.al=new A.e(B.a,"Gas stop minimum must be positive.",0)
B.am=new A.e(B.a,"Level duration is insufficient for descent.",0)
B.an=new A.e(B.a,"Bailout requires active CCR breathing at the selected runtime.",0)
B.D=new A.e(B.a,"Ascent rate must be positive.",0)
B.ao=new A.e(B.n,"Atmosphere model requires altitude0\u201311000m and positive sea-level pressure.",0)
B.ap=new A.e(B.a,"VPM parameter version is required.",0)
B.aq=new A.e(B.a,"CNS unavailable reason must identify its model domain.",0)
B.ar=new A.e(B.a,"Invalid VPM surface/vapour context.",0)
B.as=new A.e(B.a,"Gradient factors must satisfy 0 < low <= high <= 1.",0)
B.at=new A.e(B.j,"Altitude radius equation has no positive radius.",0)
B.au=new A.e(B.a,"Range endpoints must be ordered and step positive.",0)
B.av=new A.e(B.a,"Invalid VPM state metadata.",0)
B.aw=new A.e(B.a,"Initial VPM state and parameter versions differ.",0)
B.A=new A.T(2,"invalidBracket")
B.ax=new A.e(B.A,"Endpoints do not bracket a root.",0)
B.ay=new A.e(B.a,"Boyle target cannot exceed maximum first-stop pressure.",0)
B.t=new A.e(B.a,"A VPM engine requires a VPM request.",0)
B.az=new A.e(B.a,"Range must have at most10000 aligned points, including both endpoints.",0)
B.aA=new A.e(B.a,"Critical volume requires a positive phase time.",0)
B.E=new A.e(B.a,"Bailout must have a distinct identity and reference its source dive.",0)
B.aB=new A.e(B.j,"Repetitive excitation requires a positive radius denominator.",0)
B.aC=new A.e(B.a,"Stop step must be positive and last stop at least one step.",0)
B.aD=new A.e(B.a,"Result duration metrics are inconsistent.",0)
B.F=new A.e(B.a,"Dive needs an id and at least one level.",0)
B.aE=new A.e(B.a,"Impermeable descent needs its onset state.",0)
B.aF=new A.e(B.a,"Crushing update requires descent or constant depth.",0)
B.u=new A.e(B.a,"Movement cannot take zero time.",0)
B.aG=new A.e(B.a,"Budget must have positive iterations and nonnegative elapsed time.",0)
B.G=new A.aC(0,"buhlmannB")
B.H=new A.aC(1,"buhlmannC")
B.d=new A.aC(2,"vpmB")
B.aH=new A.aD(1e7)
B.aI=new A.aD(6e7)
B.aM=new A.de(null)
B.aN=new A.df(null)
B.aZ=new A.a6([0.6,1800,0.5,-1800])
B.aY=new A.a6([0.7,1620,0.6,-1500])
B.b_=new A.a6([0.8,1410,0.7,-1200])
B.aX=new A.a6([0.9,1170,0.8,-900])
B.aW=new A.a6([1.1,900,0.9,-600])
B.b0=new A.a6([1.5,570,1.1,-300])
B.b1=new A.a6([1.6,1245,1.5,-750])
B.I=s([B.aZ,B.aY,B.b_,B.aX,B.aW,B.b0,B.b1],A.ax("q<+high,intercept,low,slope(b,b,b,b)>"))
B.V=new A.T(3,"impossibleMixture")
B.aO=s([B.a,B.n,B.A,B.V,B.B,B.q,B.j,B.C],A.ax("q<T>"))
B.aP=s([B.e,B.f],A.ax("q<aY>"))
B.aQ=s([B.G,B.H,B.d],A.ax("q<aC>"))
B.v=new A.aa(0,"base")
B.be=s([B.v],t.Z)
B.aT=new A.aa(1,"noAdditionalGases")
B.aU=new A.aa(2,"noSwitches")
B.aR=s([B.v,B.aT,B.aU],t.Z)
B.bf=s([],t.I)
B.J=s([],t._)
B.aS=s([1,1.1,1.15,1.25,1.35],t.n)
B.aV=new A.bu(0,1)
B.L=new A.aj(0,"levelTravel")
B.p=new A.aj(1,"levelHold")
B.l=new A.aj(2,"ascent")
B.k=new A.aj(3,"decompression")
B.b2=A.Z("kS")
B.b3=A.Z("kT")
B.b4=A.Z("iz")
B.b5=A.Z("iA")
B.b6=A.Z("iB")
B.b7=A.Z("iC")
B.b8=A.Z("iD")
B.b9=A.Z("h")
B.ba=A.Z("iZ")
B.bb=A.Z("j_")
B.bc=A.Z("j0")
B.bd=A.Z("j1")})();(function staticFields(){$.eh=null
$.av=A.k([],A.ax("q<h>"))
$.hg=null
$.dp=0
$.fq=A.k6()
$.fW=null
$.fV=null
$.hV=null
$.hL=null
$.i1=null
$.eR=null
$.eY=null
$.fK=null
$.em=A.k([],A.ax("q<f<h>?>"))
$.aQ=null
$.bE=null
$.bF=null
$.fB=!1
$.x=B.h})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"kU","fO",()=>A.ky("_$dart_dartClosure"))
s($,"lb","ig",()=>A.k([new J.bU()],A.ax("q<be>")))
s($,"l_","i5",()=>A.ad(A.dF({
toString:function(){return"$receiver$"}})))
s($,"l0","i6",()=>A.ad(A.dF({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"l1","i7",()=>A.ad(A.dF(null)))
s($,"l2","i8",()=>A.ad(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"l5","ib",()=>A.ad(A.dF(void 0)))
s($,"l6","ic",()=>A.ad(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"l4","ia",()=>A.ad(A.hk(null)))
s($,"l3","i9",()=>A.ad(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"l8","ie",()=>A.ad(A.hk(void 0)))
s($,"l7","id",()=>A.ad(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"l9","fQ",()=>A.j5())
s($,"la","cL",()=>A.hX(B.b9))
s($,"kY","fP",()=>{A.iU()
return $.dp})})();(function nativeSupport(){!function(){var s=function(a){var m={}
m[a]=1
return Object.keys(hunkHelpers.convertToFastObject(m))[0]}
v.getIsolateTag=function(a){return s("___dart_"+a+v.isolateTag)}
var r="___dart_isolate_tags_"
var q=Object[r]||(Object[r]=Object.create(null))
var p="_ZxYxX"
for(var o=0;;o++){var n=s(p+"_"+o+"_")
if(!(n in q)){q[n]=1
v.isolateTag=n
break}}v.dispatchPropertyName=v.getIsolateTag("dispatch_record")}()
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.aG,SharedArrayBuffer:A.aG,ArrayBufferView:A.ba,DataView:A.c0,Float32Array:A.c1,Float64Array:A.c2,Int16Array:A.c3,Int32Array:A.c4,Int8Array:A.c5,Uint16Array:A.c6,Uint32Array:A.c7,Uint8ClampedArray:A.bb,CanvasPixelArray:A.bb,Uint8Array:A.c8})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.aH.$nativeSuperclassTag="ArrayBufferView"
A.bp.$nativeSuperclassTag="ArrayBufferView"
A.bq.$nativeSuperclassTag="ArrayBufferView"
A.b8.$nativeSuperclassTag="ArrayBufferView"
A.br.$nativeSuperclassTag="ArrayBufferView"
A.bs.$nativeSuperclassTag="ArrayBufferView"
A.b9.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$0=function(){return this()}
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$1$1=function(a){return this(a)}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
Function.prototype.$2$0=function(){return this()}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var s=document.scripts
function onLoad(b){for(var q=0;q<s.length;++q){s[q].removeEventListener("load",onLoad,false)}a(b.target)}for(var r=0;r<s.length;++r){s[r].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var s=A.kH
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()