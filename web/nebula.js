/* Lichtpfad – atmosphärischer Weltraum-Nebel-Hintergrund (nur Web).
 * WebGL-Fragment-Shader (Simplex-Noise, fBm 4 Oktaven, Domain-Warping) auf
 * Fullscreen-Quad, intern ~0.45x gerendert + per CSS hochskaliert, ~30 fps,
 * powerPreference 'low-power'. Sterne als DOM-Elemente (CSS-Puls) in zwei
 * Rand-Bändern. Fallback ohne WebGL / bei prefers-reduced-motion: geblurte,
 * CSS-animierte Farbflächen. Liegt hinter der (im Web transparenten) Flutter-App.
 */
(function () {
  'use strict';
  var reduce = window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var root = document.getElementById('space');
  if (!root) {
    root = document.createElement('div');
    root.id = 'space';
    document.body.insertBefore(root, document.body.firstChild);
  }

  // ---------- Sterne (DOM) in zwei Rand-Bändern (~15% links/rechts) ----------
  function buildStars() {
    var wrap = document.createElement('div');
    wrap.className = 'neb-stars';
    var colors = ['#ffffff', '#ffe9a8', '#ffd27a'];
    var sizes = [1.5, 2.5, 4];
    var n = Math.max(60, Math.min(140,
      Math.round(window.innerWidth * window.innerHeight / 15000)));
    for (var i = 0; i < n; i++) {
      var s = document.createElement('div');
      s.className = 'neb-star';
      var left = Math.random() < 0.5
        ? Math.random() * 15            // linkes Band 0–15%
        : 85 + Math.random() * 15;      // rechtes Band 85–100%
      var k = Math.random();
      var size = k < 0.6 ? sizes[0] : (k < 0.9 ? sizes[1] : sizes[2]);
      var col = colors[(Math.random() * colors.length) | 0];
      s.style.left = left + '%';
      s.style.top = (Math.random() * 100) + '%';
      s.style.width = size + 'px';
      s.style.height = size + 'px';
      s.style.background = col;
      s.style.boxShadow = '0 0 ' + (size * 2.2).toFixed(1) + 'px ' +
        (size * 0.7).toFixed(1) + 'px ' + col;
      if (reduce) {
        s.style.opacity = (0.25 + Math.random() * 0.5).toFixed(2);
      } else {
        var dur = (5 + Math.random() * 7); // 5–12 s (langsameres Flimmern)
        s.style.animationDuration = dur.toFixed(2) + 's';
        s.style.animationDelay = (-Math.random() * dur).toFixed(2) + 's';
      }
      wrap.appendChild(s);
    }
    root.appendChild(wrap);
  }

  // ---------- WebGL-Nebel ----------
  var VERT = 'attribute vec2 p;void main(){gl_Position=vec4(p,0.0,1.0);}';
  var FRAG = [
    'precision highp float;',
    'uniform vec2 u_res;uniform float u_time;',
    'uniform vec3 u_c1,u_c2,u_c3;',
    'vec3 mod289(vec3 x){return x-floor(x*(1.0/289.0))*289.0;}',
    'vec2 mod289(vec2 x){return x-floor(x*(1.0/289.0))*289.0;}',
    'vec3 permute(vec3 x){return mod289(((x*34.0)+1.0)*x);}',
    'float snoise(vec2 v){',
    ' const vec4 C=vec4(0.211324865405187,0.366025403784439,-0.577350269189626,0.024390243902439);',
    ' vec2 i=floor(v+dot(v,C.yy));vec2 x0=v-i+dot(i,C.xx);',
    ' vec2 i1=(x0.x>x0.y)?vec2(1.0,0.0):vec2(0.0,1.0);',
    ' vec4 x12=x0.xyxy+C.xxzz;x12.xy-=i1;i=mod289(i);',
    ' vec3 p=permute(permute(i.y+vec3(0.0,i1.y,1.0))+i.x+vec3(0.0,i1.x,1.0));',
    ' vec3 m=max(0.5-vec3(dot(x0,x0),dot(x12.xy,x12.xy),dot(x12.zw,x12.zw)),0.0);',
    ' m=m*m;m=m*m;vec3 x=2.0*fract(p*C.www)-1.0;vec3 h=abs(x)-0.5;',
    ' vec3 ox=floor(x+0.5);vec3 a0=x-ox;',
    ' m*=1.79284291400159-0.85373472095314*(a0*a0+h*h);',
    ' vec3 g;g.x=a0.x*x0.x+h.x*x0.y;g.yz=a0.yz*x12.xz+h.yz*x12.yw;',
    ' return 130.0*dot(m,g);}',
    'float fbm(vec2 p){float s=0.0,a=0.5;mat2 m=mat2(1.6,1.2,-1.2,1.6);',
    ' for(int i=0;i<4;i++){s+=a*snoise(p);p=m*p;a*=0.5;}return s;}',
    'void main(){',
    ' vec2 uv=gl_FragCoord.xy/u_res;',
    ' float aspect=u_res.x/u_res.y;',
    ' vec2 p=vec2((uv.x-0.5)*aspect,uv.y-0.5);',
    ' float t=u_time*0.02;',
    // Domain-Warping: fbm(p + fbm(p+t))
    ' vec2 warp=vec2(fbm(p*1.7+vec2(0.0,t)),fbm(p*1.7+vec2(4.7,-t)));',
    ' float n=fbm(p*1.9+1.7*warp+0.3*t);n=n*0.5+0.5;',
    // großräumige Maske -> dunkler Leerraum zwischen den (größeren) Wolken
    ' float mask=fbm(p*0.62+7.0-0.15*t)*0.5+0.5;',
    ' mask=smoothstep(0.46,0.86,mask);',
    ' float density=pow(clamp(n,0.0,1.0),1.9)*mask;',
    // additive Farbmischung: jede Akzentfarbe hat ihre eigene Zone (gold/braun/blau)
    ' float sel=fbm(p*1.2+3.3+0.2*t)*0.5+0.5;',
    ' float zGold=smoothstep(0.52,0.95,sel);',
    ' float zBraun=smoothstep(0.52,0.95,1.0-sel);',
    ' float zBlau=smoothstep(0.34,0.0,abs(sel-0.5));',
    ' vec3 col=vec3(0.0);',
    ' col+=u_c1*density*zGold*1.95;',
    ' col+=u_c2*density*zBraun*1.65;',
    ' col+=u_c3*density*zBlau*1.45;',
    // warme Glut in den dichtesten Kernen
    ' float core=smoothstep(0.72,1.0,density);',
    ' col+=vec3(0.72,0.88,1.0)*core*0.72;',
    // Lesbarkeits-Zone: dimmt die (verwackelt wallende) Bildmitte weich ab
    ' float band=0.175+0.05*snoise(vec2(uv.x*2.4,t));',
    ' float r=smoothstep(band*0.55,band*1.85,abs(uv.y-0.5));',
    ' col*=mix(0.10,1.0,r);',
    // sehr dunkle, leicht bläuliche Basis
    ' col+=vec3(0.047,0.059,0.086);',
    ' gl_FragColor=vec4(col,1.0);',
    '}'
  ].join('\n');

  function compile(gl, type, src) {
    var s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
      console.warn('nebula shader:', gl.getShaderInfoLog(s));
      return null;
    }
    return s;
  }

  function initGL() {
    var c = document.createElement('canvas');
    c.className = 'neb-canvas';
    var opts = { powerPreference: 'low-power', antialias: false,
      depth: false, stencil: false, alpha: false, preserveDrawingBuffer: false };
    var gl = c.getContext('webgl', opts) || c.getContext('experimental-webgl', opts);
    if (!gl) return false;

    var vs = compile(gl, gl.VERTEX_SHADER, VERT);
    var fs = compile(gl, gl.FRAGMENT_SHADER, FRAG);
    if (!vs || !fs) return false;
    var pr = gl.createProgram();
    gl.attachShader(pr, vs); gl.attachShader(pr, fs); gl.linkProgram(pr);
    if (!gl.getProgramParameter(pr, gl.LINK_STATUS)) {
      console.warn('nebula link:', gl.getProgramInfoLog(pr));
      return false;
    }
    gl.useProgram(pr);

    var buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    var loc = gl.getAttribLocation(pr, 'p');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    var uRes = gl.getUniformLocation(pr, 'u_res');
    var uTime = gl.getUniformLocation(pr, 'u_time');
    gl.uniform3f(gl.getUniformLocation(pr, 'u_c1'), 0.494, 0.784, 1.000); // Hellblau #7ec8ff
    gl.uniform3f(gl.getUniformLocation(pr, 'u_c2'), 0.231, 0.478, 0.851); // Azurblau #3b7ad9
    gl.uniform3f(gl.getUniformLocation(pr, 'u_c3'), 0.333, 0.400, 0.820); // Blauviolett #5566d1

    root.appendChild(c);
    var SCALE = 0.45;
    function resize() {
      var w = Math.max(2, Math.round(window.innerWidth * SCALE));
      var h = Math.max(2, Math.round(window.innerHeight * SCALE));
      c.width = w; c.height = h;
      gl.viewport(0, 0, w, h);
      gl.uniform2f(uRes, w, h);
      if (reduce) draw(8.0); // statisch neu zeichnen
    }
    function draw(time) { gl.uniform1f(uTime, time); gl.drawArrays(gl.TRIANGLES, 0, 3); }
    window.addEventListener('resize', resize);
    resize();

    if (reduce) { draw(8.0); return true; } // ein statisches Bild, keine Bewegung

    var start = performance.now(), last = 0;
    function loop(now) {
      if (now - last >= 33) { last = now; draw((now - start) / 1000); } // ~30 fps
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
    return true;
  }

  function fallback() {
    var f = document.createElement('div');
    f.className = 'neb-fallback' + (reduce ? ' neb-static' : '');
    f.innerHTML =
      '<span class="neb-blob b1"></span>' +
      '<span class="neb-blob b2"></span>' +
      '<span class="neb-blob b3"></span>' +
      '<span class="neb-readmask"></span>';
    root.appendChild(f);
  }

  buildStars();
  try { if (!initGL()) fallback(); }
  catch (e) { console.warn('nebula init failed:', e); fallback(); }
})();
